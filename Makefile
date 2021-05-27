OMZ_PLUGIN_PATH=$$(chezmoi source-path)/dot_omz-custom/plugins


all: \
	update-oh-my-zsh \
	update-plugins

update-oh-my-zsh:
	curl -s -L -o oh-my-zsh-master.tar.gz https://github.com/robbyrussell/oh-my-zsh/archive/master.tar.gz
	chezmoi import --strip-components 1 --destination ${HOME}/.oh-my-zsh oh-my-zsh-master.tar.gz

update-plugins: \
	update-plugins-chezmoi \
	update-plugins-zsh-autosuggestions

update-plugins-chezmoi:
	mkdir -p ${OMZ_PLUGIN_PATH}/chezmoi
	chezmoi completion zsh > ${OMZ_PLUGIN_PATH}/chezmoi/_chezmoi

update-plugins-zsh-autosuggestions:
	curl -s --create-dirs -o \
		${OMZ_PLUGIN_PATH}/zsh-autosuggestions/_zsh-autosuggestions \
		https://raw.githubusercontent.com/zsh-users/zsh-autosuggestions/master/zsh-autosuggestions.zsh
