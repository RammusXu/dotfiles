# dotfiles

![demo](./images/demo.png)

## FAQ

### 如何在新 Mac 上安裝 chezmoi？
```
sh -c "$(curl -fsLS git.io/chezmoi)" -- init --apply rammusxu
```

雖然也可以用 `brew install chezmoi` 安裝，但是有可能是新的機器，或是 Linux 機器，為了一致性，所以都用 `curl` 安裝。



### 如何更新 chezmoi？
```bash
chezmoi update
```
path: .local/share/chezmoi

`chezmoi update` 會將你的 dotfiles 更新到最新狀態。如果你想將本地的變更應用到實際檔案，可以使用 `chezmoi apply`。


### 如何取得/更新 oh-my-zsh？
不要開啟 .oh-my-zsh 的自動更新，不然 git commit 會很亂。

https://github.com/twpayne/chezmoi/blob/master/docs/HOWTO.md#include-a-subdirectory-from-another-repository-like-oh-my-zsh

```bash
make
```

### 如何更改 ZSH_CUSTOM 資料夾？
不要用 `.oh-my-zsh/custom` 當作預設，因為更新 `.oh-my-zsh` 的時候會被覆蓋掉。

`dot_zshrc.tmpl`
```
ZSH_CUSTOM="{{ .chezmoi.homeDir }}/.omz-custom"
```

### 如何新增 brew formula 或 cask？
https://www.chezmoi.io/docs/how-to/#use-chezmoi-on-macos

編輯 `./Brewfile`

### 如何新增檔案到 chezmoi？
```
chezmoi add ~/.zsh_alias.zsh
chezmoi add --autotemplate ~/.zsh_alias.zsh
```

### 如何新增自訂插件？
```
NEW_PLUGIN=chezmoi
NEW_PLUGIN_PATH=$(chezmoi source-path)/dot_omz-custom/plugins/$NEW_PLUGIN

mkdir -p $NEW_PLUGIN_PATH
chezmoi completion zsh > $NEW_PLUGIN_PATH/_$NEW_PLUGIN
```

### 如何新增 oh-my-zsh 主題？
```
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM}/themes/powerlevel10k
chezmoi add -r ${ZSH_CUSTOM}
chezmoi cd
git add dot_omz-custom
```
在 `~/.zshrc` 中設定 `ZSH_THEME="powerlevel10k/powerlevel10k"`。

### 如何設定 .ssh/config？
```
# GitLab.com
Host gitlab.com
  PreferredAuthentications publickey
  IdentityFile ~/.ssh/gitlab_com

# Github.com
Host github.com
  PreferredAuthentications publickey
  IdentityFile ~/.ssh/github_com
```

## 其他設定

### iTerm 設定
> Credit: https://apple.stackexchange.com/questions/136928/using-alt-cmd-right-left-arrow-in-iterm/136931

Preferences -> Profiles -> Keys -> Key Mappings -> Presets: `Natural Text Editing`

![iterm-keys](./images/iterm-keys.png)

### Visual Studio Code 設定
Visual Studio Code: Open File → Preferences → Settings, enter terminal.integrated.fontFamily in the search box and set the value to MesloLGS NF.