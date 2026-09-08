#!/usr/bin/env bash
# 從 Bitwarden 把 ~/.zshenv 拉回來。新機 bootstrap 的第二步。
#
# 為什麼是 ~/.zshenv：zsh 會在每個 shell 啟動時自動讀它，是放環境變數的慣例位置，
#   不用在 .zshrc 手動 source。（只顧 zsh —— 2026-09 起 bash 那條路徑連同
#   ~/.common_env 一起移除了，見 DECISIONS「zsh 的設定檔只留三個」。）
# 為什麼是 Bitwarden 而不是 chezmoi 加密：
#   這是 public repo。就算加密，密文也是公開的，只要金鑰哪天外流就全部回溯解開。
#   把 secret 完全不放進 repo，是「結構上不可能洩漏」，而不是「加密所以應該還好」。
#
# 用法： export BW_SESSION=$(bw unlock --raw) && scripts/secrets-restore.sh
#        scripts/secrets-restore.sh [bitwarden item name] [目標檔案]
set -euo pipefail

ITEM="${1:-dotfiles/zshenv}"
DEST="${2:-$HOME/.zshenv}"

command -v bw >/dev/null || { echo "需要 bitwarden-cli： brew install bitwarden-cli"; exit 1; }

if [ -z "${BW_SESSION:-}" ]; then
  echo "先解鎖： export BW_SESSION=\$(bw unlock --raw)"
  exit 1
fi

bw sync >/dev/null 2>&1 || true   # 先同步，免得抓到本機快取的舊版

if [ -e "$DEST" ]; then
  cp "$DEST" "$DEST.bak.$(date +%Y%m%d%H%M%S)"
  echo "==> 舊檔已備份"
fi

bw get notes "$ITEM" > "$DEST"
chmod 600 "$DEST"
echo "==> ✅ $DEST 已還原（600）—— 開新的 shell 或 exec zsh 生效"
