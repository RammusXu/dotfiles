#!/usr/bin/env bash
# 把 ~/.env 存進 Bitwarden 的 Secure Note，換機時用 secrets-restore.sh 拉回。
set -euo pipefail
ITEM="${1:-dotfiles/.env}"
SRC="${2:-$HOME/.env}"

command -v bw >/dev/null || { echo "需要 bitwarden-cli： brew install bitwarden-cli"; exit 1; }
[ -f "$SRC" ] || { echo "找不到 $SRC"; exit 1; }
[ -n "${BW_SESSION:-}" ] || { echo "先解鎖： export BW_SESSION=\$(bw unlock --raw)"; exit 1; }

echo "把 $SRC 的內容貼進 Bitwarden 的 Secure Note，名稱設為： $ITEM"
echo "（刻意不自動寫入 —— 建立 item 這種一次性動作用 GUI 比較不會出錯）"
echo
echo "內容行數： $(wc -l < "$SRC")"
