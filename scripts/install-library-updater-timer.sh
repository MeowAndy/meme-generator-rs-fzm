#!/usr/bin/env bash
set -euo pipefail
INSTALL_DIR=${INSTALL_DIR:-/opt/meme-api}
if [ "${EUID}" -ne 0 ]; then echo "Run as root" >&2; exit 1; fi
sed "s#__INSTALL_DIR__#$INSTALL_DIR#g" systemd/meme-library-updater.service > /etc/systemd/system/meme-library-updater.service
cp systemd/meme-library-updater.timer /etc/systemd/system/meme-library-updater.timer
systemctl daemon-reload
systemctl enable --now meme-library-updater.timer
systemctl list-timers meme-library-updater.timer --no-pager
