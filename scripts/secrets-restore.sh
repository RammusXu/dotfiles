#!/usr/bin/env bash
# 從 Bitwarden 把 ~/.env 拉回來。新機 bootstrap 的第二步。
#
# 為什麼是 Bitwarden 而不是 chezmoi 加密：
#   這是 public repo。就算加密，密文也是公開的，只要金鑰哪天外流就全部回溯解開。
#   把 secret 完全不放進 repo，是「結構上不可能洩漏」，而不是「加密所以應該還好」。
set -euo pipefail

ITEM="${1:-dotfiles/.env}"
DEST="${2:-$HOME/.env}"

command -v bw >/dev/null || { echo "需要 bitwarden-cli： brew install bitwarden-cli"; exit 1; }

if [ -z "${BW_SESSION:-}" ]; then
  echo "先解鎖： export BW_SESSION=\$(bw unlock --raw)"
  exit 1
fi

if [ -e "$DEST" ]; then
  cp "$DEST" "$DEST.bak.$(date +%Y%m%d%H%M%S)"
  echo "==> 舊檔已備份"
fi

bw get notes "$ITEM" > "$DEST"
chmod 600 "$DEST"
echo "==> ✅ $DEST 已還原（600）"
