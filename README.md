# dotfiles

chezmoi + Homebrew。一台新 Mac 從開機到能寫程式，理想上只要三個指令。

**這是 public repo，裡面沒有任何 secret。** 為什麼這樣設計、以及所有技術選擇的理由，
見 [`docs/DECISIONS.md`](docs/DECISIONS.md)。

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

**第二步（補 secret）**：

```bash
export BW_SESSION=$(bw unlock --raw)
~/.local/share/chezmoi/scripts/secrets-restore.sh
```

bootstrap 不會因為缺 secret 而失敗 —— apply 完會印出一份檢查清單告訴你還缺什麼。

## 這個 repo 的結構

| 檔案 | 作用 |
|---|---|
| `.chezmoi.toml.tmpl` | init 時問 role / isWork，決定這台機器裝什麼 |
| `.chezmoidata.yaml` | **zsh plugin 清單的單一事實來源** —— 同時決定 `.zshrc` 的 `plugins=()` 和 external 要抓哪些目錄 |
| `.chezmoiexternal.toml.tmpl` | oh-my-zsh、powerlevel10k、zsh plugins 由 chezmoi 直接抓上游 |
| `.chezmoiignore` | 擋掉 repo-only 檔案，避免被 apply 到 `$HOME` |
| `Brewfile` | CLI 工具，兩種 role 都裝 |
| `Brewfile.gui` | GUI cask，只有 `role=primary` 裝 |
| `Brewfile.manual` | 需要 sudo / MAS / 非 brew 的東西。**不會自動執行** |
| `run_onchange_after_10-brew.sh.tmpl` | 跑 brew bundle。含 Brewfile hash 觸發 |
| `run_onchange_after_20-macos-defaults.sh.tmpl` | macOS 系統偏好 |
| `run_once_after_30-install-gcloud.sh.tmpl` | gcloud 官方 archive 安裝 |
| `scripts/brewfile-audit.sh` | 比對機器實際狀態 vs Brewfile |
| `scripts/macos-defaults-dump.sh` | 舊機 dump 系統偏好當參考 |
| `scripts/secrets-restore.sh` | 從 Bitwarden 還原 `~/.env` |
| `.githooks/pre-commit` | gitleaks + pattern 檢查，擋 secret 進 public repo |
| `private_dot_ssh/private_config.tmpl` | SSH host alias（work / personal 分流）|
| `docs/DECISIONS.md` | **為什麼是這樣做** —— 技術選擇與 FAQ |

## 換機待辦（chezmoi 管不到的）

- [ ] `~/.env`：走 Bitwarden → `scripts/secrets-restore.sh`（**刻意不進版控**）
- [ ] `gh auth login`（選 HTTPS）→ `gh auth setup-git`
- [ ] SSH key：新機產新的並上傳，舊 key 留在舊機。
      remote 用 host alias（`git@github-work:...`），身分才不會打架
- [ ] `Brewfile.manual` 裡的項目（Docker Desktop 授權、Rectangle 輔助使用權限、Xnip、Orca）
- [ ] 2FA / Authenticator 轉移
- [ ] VS Code：開 Settings Sync，或 `code --list-extensions` 手動補
- [ ] Obsidian vault 與 `.obsidian/` plugin 設定
- [ ] Dock 排列、輸入法 —— 手動排，不用 script

## 日常操作

```bash
chezmoi diff       # 看會改什麼（apply 前一定先跑）
make quick         # 日常套用：跳過 externals，最快
make apply         # 完整套用（會檢查 externals 是否過期）
make refresh       # 強制重抓 oh-my-zsh / p10k 上游
chezmoi update     # 其他電腦抓最新版 = git pull + apply
make audit         # 比對 Brewfile 和機器實際狀態
```

改設定的流程：

```bash
chezmoi edit ~/.zshrc     # 改 source 檔，不是直接改 ~/.zshrc
chezmoi diff && make quick
cd $(chezmoi source-path) && git add -A && git commit && git push
```

`chezmoi re-add` **只在主力機做** —— 兩台都 re-add + push 就會開始打架。

### 新增 brew 套件
編輯 `Brewfile`（CLI）或 `Brewfile.gui`（cask），下次 apply 會自動重跑 brew bundle
—— 靠的是 `run_onchange_after_10-brew.sh.tmpl` 裡的 Brewfile hash 行。
**Brewfile 沒改就不會跑**（實測驗證，見 DECISIONS.md）。

### 新增 zsh plugin
只改 `.chezmoidata.yaml`。`.zshrc` 的 `plugins=()` 和 external 的下載清單都從那裡產生。

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
