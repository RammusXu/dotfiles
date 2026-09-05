#!/bin/bash
# 在舊機上跑，把目前的系統偏好 dump 成參考檔。
#
# 重點：dump 出來的東西是「參考文件」，不是拿去直接 apply 的來源。
# macOS 的 defaults domain 沒有正式文件、跨版本會變，整包 restore 是災難來源。
# 正確用法：翻這份 dump，挑出你真的在乎的 key，手動加進
# run_onchange_after_20-macos-defaults.sh.tmpl 並附上註解。
set -euo pipefail
OUT="${1:-$HOME/macos-defaults-baseline}"
mkdir -p "$OUT"

echo "==> dump 到 $OUT"
defaults read NSGlobalDomain                                  > "$OUT/NSGlobalDomain.txt" 2>/dev/null || true
defaults read com.apple.finder                                > "$OUT/finder.txt"        2>/dev/null || true
defaults read com.apple.dock                                  > "$OUT/dock.txt"          2>/dev/null || true
defaults read com.apple.screencapture                         > "$OUT/screencapture.txt" 2>/dev/null || true
defaults read com.apple.AppleMultitouchTrackpad               > "$OUT/trackpad.txt"      2>/dev/null || true
defaults read com.apple.driver.AppleBluetoothMultitouch.trackpad > "$OUT/trackpad-bt.txt" 2>/dev/null || true
defaults read com.apple.symbolichotkeys                       > "$OUT/hotkeys.txt"       2>/dev/null || true
defaults domains | tr ',' '\n' | sed 's/^ *//'                > "$OUT/all-domains.txt"

sw_vers > "$OUT/_macos-version.txt"
echo "==> 完成。這份請留在 repo 外或加進 .gitignore —— 裡面可能有機敏資訊。"
