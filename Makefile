# oh-my-zsh / powerlevel10k / zsh plugins 已改由 .chezmoiexternal.toml 管理，
# 不再需要手動下載 tarball + chezmoi import。
#
# 強制重抓上游：
#   make refresh

.PHONY: refresh audit diff

refresh:
	chezmoi apply --refresh-externals

audit:
	./scripts/brewfile-audit.sh

diff:
	chezmoi diff
