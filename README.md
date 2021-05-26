# dotfiles

## Install

```
sh -c "$(curl -fsLS git.io/chezmoi)"
```

雖然也可以用 `brew install chezmoi` 安裝，但是有可能是新的機器，或是 Linux 機器，為了一致性，所以都用 `curl` 安裝。

> If you already have a dotfiles repo using chezmoi on GitHub at https://github.com/<github-username>/dotfiles then you can install chezmoi and your dotfiles with the single command:

```
sh -c "$(curl -fsLS git.io/chezmoi)" -- init --apply rammusxu
```

## Init

https://github.com/new

```
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

## Add brew formula|cask

https://www.chezmoi.io/docs/how-to/#use-chezmoi-on-macos

Edit `run_once_before_20-brew-darwin.sh.tmpl`


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
