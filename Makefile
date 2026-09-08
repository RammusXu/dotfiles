# 這份 Makefile 就是「我到底該打哪個指令」的答案。直接跑 `make` 會列出全部。
# oh-my-zsh / powerlevel10k / zsh plugin 由 .chezmoiexternal.toml.tmpl 管，不在版控裡。

.DEFAULT_GOAL := help
.PHONY: help diff quick apply refresh update pull audit prune doctor secrets secrets-save

help: ## 列出所有指令
	@echo "用法： make <target>"
	@echo
	@grep -hE '^[a-z][a-z-]*:.*##' $(MAKEFILE_LIST) \
	  | sed -e 's/:.*##/\t/' \
	  | awk -F'\t' '{ printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }'
	@echo
	@echo "第一次用這台機器？看 README 的「Quick start」。"

## ---------- 日常 ----------

diff: ## 看 apply 會改什麼（動手前先跑這個）
	chezmoi diff

quick: ## 日常套用：跳過 externals，最快
	chezmoi apply --exclude=externals

apply: ## 完整套用（會檢查 externals 是否過期，refreshPeriod=168h）
	chezmoi apply

## ---------- 更新 ----------

update: ## 更新全部：brew 套件 + 上游 externals + gcloud
	@echo "==> 🍺 brew"
	brew update && brew upgrade && brew cleanup
	@echo "==> 🔄 externals（oh-my-zsh / p10k / zsh plugins）"
	chezmoi apply --refresh-externals
	@echo "==> ☁️  gcloud"
	@command -v gcloud >/dev/null 2>&1 && gcloud components update --quiet || echo "   （沒有 gcloud，略過）"
	@echo "==> ✅ 更新完成。cask 不在這裡處理 —— 它們 auto_updates，讓 app 自己更新。"

refresh: ## 只強制重抓上游 oh-my-zsh / p10k / plugins
	# --include=externals 把範圍限制在上游內容，所以 --force 是安全的
	# （不會去覆蓋你手改過的 dotfiles）。不加 --force 的話，p10k 自己編譯出來的
	# 檔案會讓 chezmoi 停下來問你，而 script 環境沒有 TTY 可以回答。
	chezmoi apply --refresh-externals --include=externals --force

pull: ## 從 GitHub 抓這份 dotfiles 的最新版並套用（= git pull + apply）
	chezmoi update

## ---------- 盤點 / 清理 ----------

audit: ## 比對機器實際狀態 vs Brewfile（唯讀）
	@./scripts/brewfile-audit.sh

prune: ## 列出「機器上有但 Brewfile 沒宣告」的東西並產生 uninstall 指令（dry-run）
	@./scripts/brew-prune.sh

doctor: ## 檢查這台機器的 chezmoi 接線有沒有接對
	@echo "source-path : $$(chezmoi source-path)"
	@echo "  應該是      : $(HOME)/personal/dotfiles"
	@test "$$(chezmoi source-path)" = "$(HOME)/personal/dotfiles" \
	  && echo "  ✅ 一致" \
	  || echo "  ❌ 不一致！見 README「編輯位置只有一個」—— 要重跑帶 --source 的 chezmoi init"
	@test -f "$(HOME)/.config/chezmoi/chezmoi.toml" \
	  && echo "✅ 有 ~/.config/chezmoi/chezmoi.toml" \
	  || echo "❌ 沒有 ~/.config/chezmoi/chezmoi.toml —— role / 公司身分都會用 fallback 值"
	@test -f "$(HOME)/.zshenv" \
	  && echo "✅ 有 ~/.zshenv（secrets）" \
	  || echo "❌ 沒有 ~/.zshenv —— 跑 make secrets"

## ---------- secrets ----------

secrets: ## 從 Bitwarden 還原 ~/.zshenv（需要先 export BW_SESSION）
	@./scripts/secrets-restore.sh

secrets-save: ## 把 ~/.zshenv 寫回 Bitwarden（先給 diff 確認；ARGS=-y 跳過確認）
	@./scripts/secrets-backup.sh $(ARGS)
