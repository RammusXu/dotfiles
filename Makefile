# oh-my-zsh / powerlevel10k / zsh plugins 由 .chezmoiexternal.toml.tmpl 管理。

.PHONY: quick apply refresh audit diff

# 日常：跳過 externals，只套用 dotfiles 與 script。最快的路徑。
quick:
	chezmoi apply --exclude=externals

# 完整套用（會檢查 externals 是否過期，refreshPeriod = 168h）
apply:
	chezmoi apply

# 強制重抓上游 oh-my-zsh / p10k / plugins
refresh:
	chezmoi apply --refresh-externals

audit:
	./scripts/brewfile-audit.sh

diff:
	chezmoi diff
