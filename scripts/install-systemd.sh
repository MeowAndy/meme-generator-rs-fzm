#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR=${INSTALL_DIR:-/opt/meme-api}
MEME_VERSION=${MEME_VERSION:-0.2.3}
MEME_ZIP_URL=${MEME_ZIP_URL:-https://github.com/MemeCrafters/meme-generator-rs/releases/download/v${MEME_VERSION}/meme-generator-cli-linux-x86_64.zip}
PROXY_HOST=${PROXY_HOST:-0.0.0.0}
PROXY_PORT=${PROXY_PORT:-2234}
API_PORT=${API_PORT:-2233}

if [ "${EUID}" -ne 0 ]; then
  echo "Please run as root." >&2
  exit 1
fi

apt-get update -y
apt-get install -y curl unzip python3 python3-requests fontconfig fonts-noto-cjk fonts-wqy-zenhei fonts-wqy-microhei

mkdir -p "$INSTALL_DIR"/{bin,data/resources,data/libraries,proxy,logs}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -L "$MEME_ZIP_URL" -o "$work/meme.zip"
unzip -o "$work/meme.zip" -d "$work/meme"
find "$work/meme" -type f -perm -111 -name 'meme*' -exec cp {} "$INSTALL_DIR/bin/meme" \; -quit
chmod +x "$INSTALL_DIR/bin/meme"

cp proxy/meme_compat_proxy.py "$INSTALL_DIR/proxy/meme_compat_proxy.py"
chmod +x "$INSTALL_DIR/proxy/meme_compat_proxy.py"
cp config/config.toml "$INSTALL_DIR/data/config.toml"
cp config/libraries.env "$INSTALL_DIR/libraries.env"

# Install default extension libraries.
INSTALL_DIR="$INSTALL_DIR" bash scripts/update-libraries.sh || true

sed "s#__INSTALL_DIR__#$INSTALL_DIR#g; s#__API_PORT__#$API_PORT#g" systemd/meme-api.service > /etc/systemd/system/meme-api.service
sed "s#__INSTALL_DIR__#$INSTALL_DIR#g; s#__PROXY_HOST__#$PROXY_HOST#g; s#__PROXY_PORT__#$PROXY_PORT#g" systemd/meme-compat-proxy.service > /etc/systemd/system/meme-compat-proxy.service
sed "s#__INSTALL_DIR__#$INSTALL_DIR#g" systemd/meme-library-updater.service > /etc/systemd/system/meme-library-updater.service
cp systemd/meme-library-updater.timer /etc/systemd/system/meme-library-updater.timer

systemctl daemon-reload
systemctl enable --now meme-api.service
systemctl enable --now meme-compat-proxy.service
systemctl enable --now meme-library-updater.timer

sleep 3
systemctl --no-pager --full status meme-api.service | head -40 || true
systemctl --no-pager --full status meme-compat-proxy.service | head -40 || true

echo "Native API: http://SERVER_IP:${API_PORT}"
echo "meme-plugin compatible API: http://SERVER_IP:${PROXY_PORT}"
