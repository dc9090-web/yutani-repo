#!/usr/bin/env bash
# Adds the [yutani] pacman repository to this machine (Arch / CachyOS).
#   curl -fsSL https://raw.githubusercontent.com/dc9090-web/yutani-repo/main/setup.sh | sudo bash
set -euo pipefail

KEY_FPR=0839A301A0D74BF69A1CF2F6513E4FFAAE611ADF
KEY_URL=https://raw.githubusercontent.com/dc9090-web/yutani-repo/main/yutani-repo.asc
CONF=/etc/pacman.conf

[[ $EUID == 0 ]] || { echo "Run as root (sudo)." >&2; exit 1; }

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
curl -fsSL "$KEY_URL" -o "$tmp"
pacman-key --add "$tmp"
pacman-key --lsign-key "$KEY_FPR"

if ! grep -q '^\[yutani\]' "$CONF"; then
  cat >>"$CONF" <<'EOF'

[yutani]
SigLevel = Required
Server = https://github.com/dc9090-web/yutani-repo/releases/download/$arch
EOF
  echo "Added [yutani] to $CONF"
else
  echo "[yutani] already in $CONF"
fi

pacman -Sy
echo
echo "Done. Install with e.g.: sudo pacman -S yutani whatsapp-cosmic-git yutani-sysmon"
