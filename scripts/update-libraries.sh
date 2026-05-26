#!/usr/bin/env bash
set -euo pipefail
INSTALL_DIR=${INSTALL_DIR:-/opt/meme-api}
ENV_FILE=${ENV_FILE:-$INSTALL_DIR/libraries.env}
LIB_DIR="$INSTALL_DIR/data/libraries"
mkdir -p "$LIB_DIR"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi
MEME_LIBRARY_URLS=${MEME_LIBRARY_URLS:-"https://github.com/anyliew/meme-emoji/releases/download/v0.0.6%2Bbuild.43/meme-emoji-linux-x86_64.so"}

changed=0
for url in $MEME_LIBRARY_URLS; do
  name=$(basename "${url%%\?*}")
  tmp=$(mktemp)
  echo "Downloading $url"
  curl -fL "$url" -o "$tmp"
  if [ ! -s "$tmp" ]; then
    echo "Downloaded file is empty: $url" >&2
    rm -f "$tmp"
    exit 1
  fi
  if [ ! -f "$LIB_DIR/$name" ] || ! cmp -s "$tmp" "$LIB_DIR/$name"; then
    install -m 0644 "$tmp" "$LIB_DIR/$name"
    changed=1
    echo "Updated $LIB_DIR/$name"
  else
    echo "No change: $name"
  fi
  rm -f "$tmp"
done

if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files meme-api.service >/dev/null 2>&1; then
  if [ "$changed" = "1" ]; then
    systemctl restart meme-api.service
    sleep 2
  fi
  systemctl is-active meme-api.service || exit 1
fi

if command -v curl >/dev/null 2>&1; then
  curl -fsS http://127.0.0.1:2233/meme/keys >/tmp/meme-keys.json || true
  if [ -s /tmp/meme-keys.json ]; then
    python3 - <<'PY' || true
import json
print('meme keys:', len(json.load(open('/tmp/meme-keys.json'))))
PY
  fi
fi
