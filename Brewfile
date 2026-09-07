# CLI 工具 — primary 與 runner 都會裝。
#
# 收錄原則（2026-09 盤點後定下來的，之後照這個判斷就好）：
#   1. 近 12 個月有使用痕跡 —— shell history，或 ~/.<tool>/ 這類 config 目錄的 mtime
#   2. 或者這套 dotfiles 自己會用到（gitleaks / bitwarden-cli）
# 兩個都不符合就移出去，需要時 `brew install` 再加回來。
# 移除了什麼、憑什麼移，全部記在 docs/INVENTORY.md。
#
#   make audit   對齊機器實際狀態 vs 這份清單
#   make prune   列出「機器上有但這裡沒宣告」的東西，並產生 uninstall 指令

tap "homebrew/bundle"
tap "derailed/k9s"     # k9s 不在 homebrew-core，只能從這個 tap 裝

# --- shell ---
# ⚠️ zsh-autosuggestions / zsh-syntax-highlighting 刻意【不】用 brew 裝。
#    它們是 oh-my-zsh custom plugin，由 .chezmoiexternal 抓上游放進 ~/.omz-custom。
#    兩邊都裝就會有兩份，實際載到哪一份要看 .zshrc，是很難查的問題。
brew "zsh"
brew "fzf"             # omz fzf plugin 要它
brew "zoxide"          # omz zoxide plugin 要它

# --- 這套 dotfiles 自己要用 ---
brew "gitleaks"        # pre-commit hook 用它擋 secret 進 public repo
brew "bitwarden-cli"   # 還原 ~/.zshenv（scripts/secrets-restore.sh）
# chezmoi 本身刻意用 curl 裝在 ~/bin —— 新機第一步不該依賴 brew，見 DECISIONS

# --- core cli ---
brew "git"
brew "gh"
brew "jq"
brew "yq"
brew "tree"
brew "bat"
brew "htop"
brew "wget"
brew "curl"
brew "mtr"             # 查網路問題主力
brew "telnet"          # 測 port 通不通
brew "rtk"             # Claude Code 的 token proxy，天天在用

# --- 搜尋三件套 ---
# 各管一件事，不是互相取代（見 docs/INVENTORY.md）：
#   ripgrep 內容搜尋（預設尊重 .gitignore）—— 這件事上沒有對手
#   fd      檔名搜尋，不是 rg 的競品而是互補
#   fzf     互動式過濾，接在任何輸出後面（宣告在上面的 shell 區）
# rg / fd 的補完由 brew 的 site-functions 提供，不需要 oh-my-zsh plugin。
brew "ripgrep"
brew "fd"

# --- kubernetes ---
brew "kubernetes-cli"
brew "kubectx"
brew "k9s"

# --- iac / cloud ---
brew "opentofu"        # terraform 的替代，只留一個：tofu
brew "awscli"
brew "azure-cli"
brew "saml2aws"        # 用 SAML/SSO 換 AWS 短期憑證

# --- containers ---
brew "docker-compose"
brew "podman"

# --- languages / runtimes ---
brew "go"
brew "node"            # 版本管理不用 nvm，需要多版本再說
brew "uv"              # Python 工具鏈（取代 pipx）
brew "rbenv"           # ~/workspace 有 Gemfile 專案
brew "ruby-build"

# --- data ---
brew "postgresql@17"   # 主要是 psql client（keg-only，PATH 在 ~/.zprofile 補）
