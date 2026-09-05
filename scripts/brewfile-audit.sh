#!/bin/bash
# 在 Mac 上跑（不是在 chezmoi 的 Linux 環境）。
# 比對「機器上實際手動裝的東西」和「Brewfile 宣告的東西」的差異。
set -euo pipefail
SRC="$(chezmoi source-path)"

echo "===== 機器上有、Brewfile 沒宣告（漏掉的） ====="
comm -23 \
  <(brew leaves | sort) \
  <(grep -h '^brew "' "$SRC/Brewfile" | sed 's/^brew "\(.*\)".*/\1/' | sort)

echo
echo "===== Brewfile 宣告了、機器上沒有（新機會補裝） ====="
comm -13 \
  <(brew leaves | sort) \
  <(grep -h '^brew "' "$SRC/Brewfile" | sed 's/^brew "\(.*\)".*/\1/' | sort)

echo
echo "===== Cask：機器上有、Brewfile.gui 沒宣告 ====="
comm -23 \
  <(brew list --cask | sort) \
  <(grep -h '^cask "' "$SRC/Brewfile.gui" | sed 's/^cask "\(.*\)".*/\1/' | sort)

echo
echo "===== 佔空間前 15 名（清理參考） ====="
brew list --formula | xargs -n1 -I{} sh -c 'echo "$(du -sk $(brew --prefix)/Cellar/{} 2>/dev/null | cut -f1) {}"' 2>/dev/null | sort -rn | head -15
