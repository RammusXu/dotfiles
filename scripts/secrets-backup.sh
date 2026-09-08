#!/usr/bin/env bash
# 把 ~/.zshenv 寫進 Bitwarden 的 Secure Note，換機時用 secrets-restore.sh 拉回。
#
# secret 全程走 stdin（jq --rawfile 讀檔 → bw encode → bw create/edit item），
# 不經過 argv，所以不會出現在 shell history 或 ps 的 process list 裡。
#
# 用法： export BW_SESSION=$(bw unlock --raw) && scripts/secrets-backup.sh
#        scripts/secrets-backup.sh [-y] [bitwarden item name] [來源檔案]
set -euo pipefail

ASSUME_YES=0
POS1=""; POS2=""; npos=0
for a in "$@"; do          # 不用 array：macOS 內建的 bash 3.2 在 set -u 下抓空 array 會炸
  case "$a" in
    -y|--yes) ASSUME_YES=1 ;;
    *) npos=$((npos + 1))
       if [ "$npos" = 1 ]; then POS1="$a"; else POS2="$a"; fi ;;
  esac
done

ITEM="${POS1:-dotfiles/zshenv}"
SRC="${POS2:-$HOME/.zshenv}"

command -v bw >/dev/null || { echo "需要 bitwarden-cli： brew install bitwarden-cli"; exit 1; }
command -v jq >/dev/null || { echo "需要 jq： brew install jq"; exit 1; }
[ -f "$SRC" ] || { echo "找不到 $SRC"; exit 1; }
[ -n "${BW_SESSION:-}" ] || { echo "先解鎖： export BW_SESSION=\$(bw unlock --raw)"; exit 1; }

confirm() { # $1 = 提示字串
  [ "$ASSUME_YES" = 1 ] && return 0
  if [ ! -t 0 ]; then
    echo "非互動環境，要自動確認請加 -y"; exit 1
  fi
  read -r -p "$1 [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

bw sync >/dev/null 2>&1 || true   # 先同步，免得對到本機快取的舊版

# 只認「名稱完全相同」的 item —— --search 會連 notes 一起模糊比對，不能直接信
matches="$(bw list items --search "$ITEM" | jq -c --arg n "$ITEM" '[.[] | select(.name == $n)]')"
count="$(jq 'length' <<<"$matches")"

if [ "$count" -gt 1 ]; then
  echo "Bitwarden 裡有 $count 個叫「${ITEM}」的 item，不敢猜要覆蓋哪個。"
  echo "先去 GUI 清成一個再跑。"
  exit 1
fi

if [ "$count" -eq 0 ]; then
  echo "Bitwarden 裡沒有「${ITEM}」，將**新建**一個 Secure Note（$(wc -l < "$SRC" | tr -d ' ') 行）。"
  confirm "要建立嗎？" || { echo "取消。"; exit 1; }
  jq -n --arg name "$ITEM" --rawfile notes "$SRC" \
    '{type:2, name:$name, notes:$notes, secureNote:{type:0}}' \
    | bw encode | bw create item >/dev/null
  echo "==> ✅ 已建立 Secure Note「${ITEM}」"
else
  item="$(jq -c '.[0]' <<<"$matches")"
  id="$(jq -r '.id' <<<"$item")"
  type="$(jq -r '.type' <<<"$item")"
  [ "$type" = 2 ] || echo "⚠️  「${ITEM}」不是 Secure Note（type=${type}），只會覆蓋它的 notes 欄位。"

  if jq -j '.notes // ""' <<<"$item" | diff -q - "$SRC" >/dev/null 2>&1; then
    echo "==> 內容跟 Bitwarden 上的一樣，不用更新。"
    exit 0
  fi

  echo "「${ITEM}」將被覆蓋。跟遠端的差異（< 是 Bitwarden，> 是 ${SRC}）："
  jq -j '.notes // ""' <<<"$item" | diff - "$SRC" | sed -E 's/^([<>] [^=]*=).*/\1<省略>/' || true
  echo
  confirm "要覆蓋嗎？" || { echo "取消。"; exit 1; }
  jq -c --rawfile notes "$SRC" '.notes = $notes' <<<"$item" \
    | bw encode | bw edit item "$id" >/dev/null
  echo "==> ✅ 已更新 Secure Note「${ITEM}」"
fi

echo "在【另一台】機器驗證： bw sync && scripts/secrets-restore.sh"
