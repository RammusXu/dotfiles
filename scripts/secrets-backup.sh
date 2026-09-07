#!/usr/bin/env bash
# 把 ~/.zshenv 存進 Bitwarden 的 Secure Note，換機時用 secrets-restore.sh 拉回。
#
# 用法： export BW_SESSION=$(bw unlock --raw) && scripts/secrets-backup.sh
#        scripts/secrets-backup.sh [bitwarden item name] [來源檔案]
set -euo pipefail
ITEM="${1:-dotfiles/zshenv}"
SRC="${2:-$HOME/.zshenv}"

command -v bw >/dev/null || { echo "需要 bitwarden-cli： brew install bitwarden-cli"; exit 1; }
[ -f "$SRC" ] || { echo "找不到 $SRC"; exit 1; }
[ -n "${BW_SESSION:-}" ] || { echo "先解鎖： export BW_SESSION=\$(bw unlock --raw)"; exit 1; }

echo "把 $SRC 的內容貼進 Bitwarden 的 Secure Note，名稱設為： $ITEM"
echo "（刻意不自動寫入 —— 建立/覆蓋 item 這種動作用 GUI 比較不會出錯，"
echo "  也不會把整份 secret 塞進 shell history 或 process list）"
echo
echo "內容行數： $(wc -l < "$SRC")"
echo
echo "存完之後在【另一台】機器驗證： bw sync && scripts/secrets-restore.sh"
