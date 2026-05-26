#!/usr/bin/env bash
set -euo pipefail
HOST=${HOST:-127.0.0.1}
API_PORT=${API_PORT:-2233}
PROXY_PORT=${PROXY_PORT:-2234}

echo "== native version =="
curl -fsS "http://$HOST:$API_PORT/meme/version"; echo

echo "== native keys =="
curl -fsS "http://$HOST:$API_PORT/meme/keys" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))'

echo "== compat keys =="
curl -fsS "http://$HOST:$PROXY_PORT/memes/keys" | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))'

echo "== compat info petpet =="
curl -fsS "http://$HOST:$PROXY_PORT/memes/petpet/info" | python3 -c 'import sys,json; o=json.load(sys.stdin); print(o.get("key"), o.get("params_type"))'
