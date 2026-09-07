#!/usr/bin/env bash
# 比對「機器實際狀態」與「Brewfile 宣告」的差異。唯讀，不會改任何東西。
# 要真的清掉多出來的東西： scripts/brew-prune.sh
#
# 在 Mac 上跑（不是在 chezmoi 的 template 環境）。
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib-brewfile.sh"

command -v brew >/dev/null || { echo "沒有 brew，這支 script 只在 Mac 上有意義"; exit 1; }
echo "repo: $REPO"
echo

section "機器上手動裝了、Brewfile 沒宣告（→ 該加進 Brewfile，或 make prune 清掉）" \
    comm -23 <(installed_leaves) <(declared_formulae)

section "Brewfile 宣告了、機器上沒有（→ 下次 apply 會補裝）" \
    comm -13 <(installed_formulae) <(declared_formulae)

section "Cask：機器上有、又沒列進任何清單（真正的偏移）" \
    comm -23 <(installed_casks) <(keep_casks)

section "Cask：Brewfile.gui 宣告了、機器上沒有" \
    comm -13 <(installed_casks) <(declared_casks)

section "Tap：機器上有、Brewfile 沒宣告（多半是舊的，可以 untap）" \
    comm -23 <(installed_taps) <(declared_taps)

section "刻意保留但不管理（Brewfile.unmanaged）—— prune 不會刪這些" \
    comm -12 <(installed_casks) <(unmanaged_casks)

echo "── 佔空間前 10 名（清理參考）"
du -sk /opt/homebrew/Cellar/*/ 2>/dev/null \
  | sort -rn | head -10 \
  | awk '{ printf "   %6.0f MB  %s\n", $1/1024, $2 }'
