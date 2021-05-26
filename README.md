# dotfiles

## Init

```
sh -c "$(curl -fsLS git.io/chezmoi)" -- init --apply rammusxu
chezmoi init --apply rammusxu
```

### Get oh-my-zsh

https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/templates/zshrc.zsh-template

https://github.com/twpayne/chezmoi/blob/master/docs/HOWTO.md#include-a-subdirectory-from-another-repository-like-oh-my-zsh

```bash
curl -s -L -o oh-my-zsh-master.tar.gz https://github.com/robbyrussell/oh-my-zsh/archive/master.tar.gz
mkdir -p $(chezmoi source-path)/dot_oh-my-zsh
chezmoi import --strip-components 1 --destination ${HOME}/.oh-my-zsh oh-my-zsh-master.tar.gz

```
## Update
```bash
chezmoi update
```

## Add new file
```
chezmoi add --autotemplate ~/.zsh_alias.zsh
```

## Add custom plugin
```
NEW_PLUGIN=chezmoi
NEW_PLUGIN_PATH=$(chezmoi source-path)/dot_omz-custom/plugins/$NEW_PLUGIN

mkdir -p $NEW_PLUGIN_PATH
chezmoi completion zsh > $NEW_PLUGIN_PATH/_$NEW_PLUGIN
```
