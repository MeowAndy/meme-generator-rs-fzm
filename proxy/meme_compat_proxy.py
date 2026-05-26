#!/usr/bin/env python3
"""Compatibility proxy for old Yunzai meme-plugin API.

Old meme-plugin expects endpoints like:
- GET  /memes/keys
- GET  /memes/{key}/info with params_type
- GET/POST /memes/{key}/preview returning image bytes
- POST /memes/{key}/ returning image bytes

meme-generator-rs exposes a newer API and returns image_id JSON. This proxy
bridges the formats and optionally falls back to an old remote API for missing
keys.
"""
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
import argparse
import cgi
import json
import os
import re
import traceback

import requests

BACKEND = os.getenv("MEME_BACKEND", "http://127.0.0.1:2233").rstrip("/")
FALLBACK = os.getenv("MEME_FALLBACK", "https://meme.pippi.top/pippi").rstrip("/")
ENABLE_FALLBACK = os.getenv("MEME_ENABLE_FALLBACK", "1") not in {"0", "false", "False", "no"}


class Handler(BaseHTTPRequestHandler):
    server_version = "meme-compat-proxy/1.1"

    def log_message(self, fmt, *args):
        print("[%s] %s" % (self.log_date_time_string(), fmt % args), flush=True)

    def send_bytes(self, code, data, ctype="application/octet-stream"):
        if isinstance(data, str):
            data = data.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def send_json(self, obj, code=200):
        self.send_bytes(code, json.dumps(obj, ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")

    def backend_image(self, image_id):
        r = requests.get(f"{BACKEND}/image/{image_id}", timeout=60)
        return r.status_code, r.content, r.headers.get("content-type", "application/octet-stream")

    def normalize_info(self, obj):
        if isinstance(obj, dict) and "params_type" not in obj and isinstance(obj.get("params"), dict):
            params = dict(obj.get("params") or {})
            params.setdefault("min_images", 0)
            params.setdefault("max_images", 0)
            params.setdefault("min_texts", 0)
            params.setdefault("max_texts", 0)
            params.setdefault("default_texts", [])
            params.setdefault("args_type", None)
            obj = dict(obj)
            obj["params_type"] = params
        return obj

    def proxy_json(self, path):
        if path in ("/meme/keys", "/memes/keys"):
            keys = []
            sources = [(BACKEND, "/meme/keys")]
            if ENABLE_FALLBACK:
                sources.append((FALLBACK, "/memes/keys"))
            for base, real_path in sources:
                try:
                    rr = requests.get(base + real_path, timeout=30)
                    if rr.ok:
                        keys.extend(rr.json())
                except Exception as exc:
                    print(f"key source failed: {base}: {exc}", flush=True)
            return self.send_json(sorted(set(keys)))

        r = requests.get(BACKEND + path, timeout=20)
        if r.ok and path.endswith("/info"):
            try:
                return self.send_json(self.normalize_info(r.json()))
            except Exception:
                pass

        if ENABLE_FALLBACK and (r.status_code == 404 or b"Meme not found" in r.content):
            try:
                fb_path = path.replace("/meme/", "/memes/")
                fr = requests.get(FALLBACK + fb_path, timeout=30)
                if fr.ok:
                    return self.send_bytes(fr.status_code, fr.content, fr.headers.get("content-type", "application/json"))
            except Exception as exc:
                print(f"fallback json failed: {exc}", flush=True)
        return self.send_bytes(r.status_code, r.content, r.headers.get("content-type", "application/json"))

    def preview(self, key):
        r = requests.post(f"{BACKEND}/memes/{key}/preview", json={}, timeout=60)
        if not r.ok or b"Meme not found" in r.content:
            if ENABLE_FALLBACK:
                for method in (requests.get, requests.post):
                    try:
                        fr = method(f"{FALLBACK}/memes/{key}/preview", timeout=60)
                        if fr.ok:
                            return self.send_bytes(fr.status_code, fr.content, fr.headers.get("content-type", "application/octet-stream"))
                    except Exception:
                        pass
            return self.send_bytes(r.status_code, r.content, r.headers.get("content-type", "application/json"))
        image_id = r.json().get("image_id")
        code, data, ctype = self.backend_image(image_id)
        self.send_bytes(code, data, ctype)

    def do_GET(self):
        p = urlparse(self.path).path.rstrip("/")
        if p in ("/health", ""):
            return self.send_json({"ok": True, "backend": BACKEND, "fallback": FALLBACK if ENABLE_FALLBACK else None})
        if p in ("/memes/keys", "/meme/keys"):
            return self.proxy_json(p)
        if p == "/meme/version":
            return self.proxy_json("/meme/version")
        m = re.fullmatch(r"/memes/([^/]+)/info", p)
        if m:
            return self.proxy_json(f"/memes/{m.group(1)}/info")
        m = re.fullmatch(r"/memes/([^/]+)/preview", p)
        if m:
            return self.preview(m.group(1))
        m = re.fullmatch(r"/image/([^/]+)", p)
        if m:
            code, data, ctype = self.backend_image(m.group(1))
            return self.send_bytes(code, data, ctype)
        self.send_bytes(404, b"not found", "text/plain")

    def do_POST(self):
        try:
            p = urlparse(self.path).path.rstrip("/")
            m = re.fullmatch(r"/memes/([^/]+)/preview", p)
            if m:
                return self.preview(m.group(1))

            m = re.fullmatch(r"/memes/([^/]+)", p)
            if not m:
                return self.send_bytes(404, b"not found", "text/plain")
            key = m.group(1)
            ctype = self.headers.get("content-type", "")
            texts = []
            files = []

            if "multipart/form-data" in ctype:
                fs = cgi.FieldStorage(fp=self.rfile, headers=self.headers, environ={"REQUEST_METHOD": "POST", "CONTENT_TYPE": ctype})
                for item in (fs.list or []):
                    if item.name == "texts":
                        texts.append(item.value)
                    elif item.name == "images" and item.file:
                        files.append((item.filename or f"image{len(files)}.png", item.file.read(), item.type or "image/png"))
            else:
                length = int(self.headers.get("content-length") or 0)
                body = self.rfile.read(length) if length else b"{}"
                try:
                    texts = json.loads(body.decode() or "{}").get("texts") or []
                except Exception:
                    pass

            images = []
            for name, data, mt in files:
                rr = requests.post(f"{BACKEND}/image/upload/multipart", files={"file": (name, data, mt)}, timeout=60)
                if not rr.ok:
                    return self.send_bytes(rr.status_code, rr.content, rr.headers.get("content-type", "application/json"))
                images.append({"name": name, "id": rr.json()["image_id"]})

            rr = requests.post(f"{BACKEND}/memes/{key}", json={"images": images, "texts": texts, "options": {}}, timeout=120)
            if not rr.ok or b"Meme not found" in rr.content:
                if ENABLE_FALLBACK:
                    try:
                        multipart = []
                        for t in texts:
                            multipart.append(("texts", (None, t)))
                        for name, data, mt in files:
                            multipart.append(("images", (name, data, mt)))
                        fr = requests.post(f"{FALLBACK}/memes/{key}/", files=multipart if multipart else None, timeout=120)
                        if fr.ok:
                            return self.send_bytes(fr.status_code, fr.content, fr.headers.get("content-type", "application/octet-stream"))
                    except Exception as exc:
                        print(f"fallback generate failed: {exc}", flush=True)
                return self.send_bytes(rr.status_code, rr.content, rr.headers.get("content-type", "application/json"))

            image_id = rr.json().get("image_id")
            code, data, resp_ct = self.backend_image(image_id)
            self.send_bytes(code, data, resp_ct)
        except Exception as exc:
            traceback.print_exc()
            self.send_json({"error": str(exc)}, 500)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default=os.getenv("MEME_PROXY_HOST", "0.0.0.0"))
    parser.add_argument("--port", type=int, default=int(os.getenv("MEME_PROXY_PORT", "2234")))
    args = parser.parse_args()
    print(f"meme compat proxy listening on {args.host}:{args.port}, backend={BACKEND}, fallback={FALLBACK if ENABLE_FALLBACK else None}", flush=True)
    ThreadingHTTPServer((args.host, args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
