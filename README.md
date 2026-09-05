# dotfiles

chezmoi + Homebrew。一台新 Mac 從開機到能寫程式，理想上只要兩個指令。

## 新機開機（Bootstrap）

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply rammusxu
```

`init` 會問兩個問題：

| 問題 | 答法 |
|---|---|
| `role` | `primary` = 日常主力機（裝 GUI app）/ `runner` = 備援背景機（只裝 CLI） |
| `isWork` | 誠品工作機填 `yes` → git 身分用 `rammusxu@eslite.com` |

跑完之後**還要手動做的事**，見下方「換機待辦」。

## 這個 repo 的結構

| 檔案 | 作用 |
|---|---|
| `.chezmoi.toml.tmpl` | init 時問 role / isWork，決定這台機器裝什麼 |
| `.chezmoiexternal.toml` | oh-my-zsh、powerlevel10k、zsh plugins 由 chezmoi 直接抓上游 |
| `.chezmoiignore` | 擋掉 repo-only 檔案，避免被 apply 到 `$HOME` |
| `Brewfile` | CLI 工具，兩種 role 都裝 |
| `Brewfile.gui` | GUI cask，只有 `role=primary` 裝 |
| `Brewfile.manual` | 需要 sudo / MAS / 非 brew 的東西。**不會自動執行** |
| `run_onchange_after_10-brew.sh.tmpl` | 跑 brew bundle。含 Brewfile hash 觸發 |
| `run_onchange_after_20-macos-defaults.sh.tmpl` | macOS 系統偏好 |
| `run_once_after_30-install-gcloud.sh.tmpl` | gcloud 官方 archive 安裝 |
| `scripts/brewfile-audit.sh` | 比對機器實際狀態 vs Brewfile |
| `scripts/macos-defaults-dump.sh` | 舊機 dump 系統偏好當參考 |

## 換機待辦（chezmoi 管不到的）

- [ ] 複製舊機的 `~/.env`（**刻意不進版控**，裡面是 secrets）
- [ ] SSH key：建議新機產新的並上傳 GitHub / GitLab，舊 key 留在舊機
- [ ] `Brewfile.manual` 裡的項目（Docker Desktop 授權、Rectangle 輔助使用權限、Xnip、Orca）
- [ ] 2FA / Authenticator 轉移
- [ ] VS Code：開 Settings Sync，或 `code --list-extensions` 手動補
- [ ] Obsidian vault 與 `.obsidian/` plugin 設定
- [ ] Dock 排列、輸入法 —— 手動排，不用 script

## 日常操作

```bash
chezmoi diff                    # 看會改什麼（apply 前一定先跑）
chezmoi apply                   # 套用
chezmoi update                  # pull + apply
make refresh                    # 強制重抓 oh-my-zsh / p10k 上游
make audit                      # 比對 Brewfile 和機器實際狀態
```

### 新增 brew 套件
編輯 `Brewfile`（CLI）或 `Brewfile.gui`（cask），下次 `chezmoi apply` 會自動重跑 brew bundle
—— 靠的是 `run_onchange_after_10-brew.sh.tmpl` 裡的 Brewfile hash 行。

### 新增檔案
```bash
chezmoi add ~/.foo
chezmoi add --autotemplate ~/.foo   # 需要跨機器變動時
```

## 兩台機器的同步紀律

**新機是唯一的 source of truth。**

- 新機：`chezmoi add` / `re-add` → commit → push
- 舊機：**只** `chezmoi update`，不 re-add、不 push

兩台都往上推，遲早會遇到不想在半夜 debug 的 merge conflict。
