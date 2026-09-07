#!/usr/bin/env bash
# 把「機器上有、但 Brewfile 沒宣告」的東西清掉。
#
# 預設 dry-run：只印出要跑的指令，什麼都不動。確定了才加 --yes。
#
#   scripts/brew-prune.sh          # 看看會清什麼
#   scripts/brew-prune.sh --yes    # 真的清
#
# 只處理「多裝」這個方向；「宣告了但沒裝」交給 chezmoi apply 補裝。
#
# 相容性：macOS 內建的 bash 是 3.2，所以這裡不用 mapfile / declare -A / ${arr[@]:-}。
set -o pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib-brewfile.sh"

DO_IT=0
[ "${1:-}" = "--yes" ] && DO_IT=1

command -v brew >/dev/null || { echo "沒有 brew"; exit 1; }

collect() {  # 把 stdin 的每一行塞進以 $1 命名的全域變數（換行分隔）
    local varname="$1" acc="" line
    while IFS= read -r line; do
        [ -n "$line" ] && acc="${acc}${line}"$'\n'
    done
    eval "$varname=\$acc"
}

collect EXTRA_FORMULAE < <(comm -23 <(installed_leaves) <(keep_formulae))
collect EXTRA_CASKS    < <(comm -23 <(installed_casks) <(keep_casks))
collect EXTRA_TAPS     < <(comm -23 <(installed_taps) <(declared_taps))

if [ -z "$EXTRA_FORMULAE$EXTRA_CASKS$EXTRA_TAPS" ]; then
    echo "✅ 機器狀態跟 Brewfile 一致，沒有東西要清。"
    exit 0
fi

oneline() { echo "$1" | tr '\n' ' ' | sed 's/ *$//'; }

echo "以下東西在機器上，但 Brewfile / Brewfile.gui 沒有宣告："
[ -n "$EXTRA_FORMULAE" ] && echo "  formula: $(oneline "$EXTRA_FORMULAE")"
[ -n "$EXTRA_CASKS" ]    && echo "  cask   : $(oneline "$EXTRA_CASKS")"
[ -n "$EXTRA_TAPS" ]     && echo "  tap    : $(oneline "$EXTRA_TAPS")"
echo
echo "⚠️  真的還要用的東西，正確做法是【加進 Brewfile】，不是在這裡刪掉。"
echo

CMDFILE="$(mktemp)"
trap 'rm -f "$CMDFILE"' EXIT
[ -n "$EXTRA_FORMULAE" ] && echo "brew uninstall $(oneline "$EXTRA_FORMULAE")" >> "$CMDFILE"
[ -n "$EXTRA_CASKS" ]    && echo "brew uninstall --cask $(oneline "$EXTRA_CASKS")" >> "$CMDFILE"
if [ -n "$EXTRA_TAPS" ]; then
    echo "$EXTRA_TAPS" | while IFS= read -r t; do
        [ -n "$t" ] && echo "brew untap $t" >> "$CMDFILE"
    done
fi
{ echo "brew autoremove"; echo "brew cleanup -s"; } >> "$CMDFILE"

echo "要執行的指令："
sed 's/^/  /' "$CMDFILE"
echo

if [ "$DO_IT" -ne 1 ]; then
    echo "（dry-run。確定了就加 --yes）"
    exit 0
fi

while IFS= read -r c; do
    echo "==> $c"
    eval "$c" || echo "    ⚠️  失敗，跳過（可能需要 sudo，或有其他東西依賴它）"
done < "$CMDFILE"

# 迭代：拔掉一層之後，原本「被它需要」的東西才會浮上來變成新的 leaf。
#
# 為什麼不能只跑一次 + brew autoremove：brew 只會 autoremove「不是 on-request」的
# 套件。一個當初被手動裝過、現在沒人要的套件（例：gdk-pixbuf）會永遠留著，
# 而它底下整串依賴（cairo / pango / ghostscript …）也因為「被它需要」而免疫。
# 2026-09 實測：這一圈多清掉約 500 MB。
for i in 1 2 3 4 5 6 7 8 9 10; do
    NEXT="$(comm -23 <(installed_leaves) <(keep_formulae) | tr '\n' ' ' | sed 's/ *$//')"
    [ -z "$NEXT" ] && break
    echo "==> 第 $i 圈：$NEXT"
    brew uninstall $NEXT </dev/null >/dev/null 2>&1 || echo "    ⚠️  這一圈有項目失敗"
    brew autoremove </dev/null >/dev/null 2>&1 || true
done

echo "==> ✅ 清理完成。再跑一次 scripts/brewfile-audit.sh 確認。"
