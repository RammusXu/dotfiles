#!/usr/bin/env bash
# brewfile-audit.sh / brew-prune.sh 共用的解析邏輯。單獨執行沒有意義。
#
# 為什麼不用 `chezmoi source-path` 找 repo：那個值來自 ~/.config/chezmoi/chezmoi.toml，
# 一旦那個檔不存在或 sourceDir 沒設對，就會指到 ~/.local/share/chezmoi 這種舊 clone，
# 然後整份比對結果都是誤報（實際踩過）。script 就住在 repo 裡，用自己的位置最可靠。
if [ -z "${BASH_SOURCE[0]:-}" ]; then
    echo "lib-brewfile.sh 只能被 bash script source。" >&2
    echo "（在 zsh 手動 source 的話 BASH_SOURCE 是空的，REPO 會靜靜地指到錯的目錄）" >&2
    return 1 2>/dev/null || exit 1
fi
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

declared_formulae() { sed -n 's/^brew "\([^"]*\)".*/\1/p' "$REPO/Brewfile" | sort -u; }
declared_casks()    { sed -n 's/^cask "\([^"]*\)".*/\1/p' "$REPO/Brewfile.gui" | sort -u; }
declared_taps()     { sed -n 's/^tap "\([^"]*\)".*/\1/p' "$REPO/Brewfile" "$REPO/Brewfile.gui" | sort -u; }

# Brewfile.unmanaged：機器上刻意留著、但不進「新機要裝」清單的東西。
# brew bundle 不會讀它；只有 prune 會，用來避免把還在用的東西列進 uninstall。
unmanaged_formulae() { sed -n 's/^brew "\([^"]*\)".*/\1/p' "$REPO/Brewfile.unmanaged" 2>/dev/null | sort -u; }
unmanaged_casks()    { sed -n 's/^cask "\([^"]*\)".*/\1/p' "$REPO/Brewfile.unmanaged" 2>/dev/null | sort -u; }
# prune 判斷「多裝」時，宣告過的 + 刻意保留的都算「不要刪」
keep_formulae() { cat <(declared_formulae) <(unmanaged_formulae) | sort -u; }
keep_casks()    { cat <(declared_casks) <(unmanaged_casks) | sort -u; }

# leaves = 手動裝的頂層套件。比對「多裝了什麼」要用這個，才不會把依賴當成多的。
installed_leaves()   { brew leaves | sort -u; }
# list  = 含依賴的全部。比對「少裝了什麼」要用這個，否則被別人依賴到的套件會被誤判為沒裝。
installed_formulae() { brew list --formula | sort -u; }
installed_casks()    { brew list --cask | sort -u; }
installed_taps()     { brew tap | sort -u; }

# 註：這裡刻意【沒有】「宣告清單 + 遞歸依賴 vs 已裝清單」這種孤兒偵測。
# 試過，不可行：brew deps 是拿【現在的 formula 定義】去解，跟這台機器【當初裝的】
# 版本對不上（awscli 現在寫 python@3.14，機器上是 python@3.13；postgresql@17 現在
# 寫 icu4c@78，機器上還有 icu4c@77 給舊 build 用），結果 35 項全是誤報。
#
# 正確的判斷只有一個：brew leaves 之外 + 沒宣告 = 該清。埋在依賴底下的東西
# 會在上一層被拔掉之後自己浮上來 —— 所以 brew-prune.sh 是【迭代】的。

# 印出 comm 的結果；空的話印一行 ✅，不要留白讓人以為壞了
section() {
    local title="$1"; shift
    echo "── $title"
    local out; out="$("$@")"
    if [ -z "$out" ]; then echo "   ✅ 一致"; else echo "$out" | sed 's/^/   /'; fi
    echo
}
