# Runbook — 日常怎麼操作

「怎麼做」在這裡。「為什麼這樣設計」在 [`DECISIONS.md`](DECISIONS.md)，
「裝了什麼、為什麼不裝別的」在 [`INVENTORY.md`](INVENTORY.md)。

最常用的兩件事（新機 / 更新套件）在 [README 的 Quick start](../README.md)，
這份是完整版與例外處理。

- [1. 更新](#1-更新)
- [2. 改設定 → 進版控](#2-改設定--進版控)
- [3. 新機完整流程](#3-新機完整流程)
- [4. 這些機制怎麼運作](#4-這些機制怎麼運作)
- [5. 常見問題](#5-常見問題)
- [6. 出事了怎麼查](#6-出事了怎麼查)

---

## 1. 更新

**四種東西的更新路徑完全不同**，搞混就會出現「明明 upgrade 過卻沒變」：

| 要更新的東西 | 指令 | 說明 |
|---|---|---|
| brew 套件（CLI） | `make update` | `brew update && upgrade && cleanup`，並順手做下面的 externals 和 gcloud |
| oh-my-zsh / p10k / zsh plugin | `make refresh` | 由 `.chezmoiexternal` 抓上游。平常有 `refreshPeriod = 168h`，`refresh` 是強制立刻抓 |
| GUI app（cask） | **不用管** | 全部 `auto_updates true`，app 自己更新。不要用 `brew upgrade --cask --greedy` 去接管 |
| gcloud | `gcloud components update` | 官方 archive 裝的，不走 brew（`make update` 已含） |
| 這份 dotfiles 本身 | `make pull` | = `chezmoi update` = git pull + apply |

改了 `Brewfile` **不需要**手動跑 brew bundle —— 下次 `make apply` 會自動重跑，
機制見 [brew 只在 Brewfile 真的變了才重跑](#brew-只在-brewfile-真的變了才重跑)。

### 加套件

編輯 `Brewfile`（CLI）或 `Brewfile.gui`（GUI cask），然後 `make apply`。

### 減套件

從 `Brewfile` 拿掉那一行 —— 注意這**不會**解除安裝，只是不再管理。

```bash
make audit                       # 列出機器實際狀態 vs Brewfile 的所有差集（唯讀）
make prune                       # 產生 uninstall 指令但不執行（dry-run）
./scripts/brew-prune.sh --yes    # 真的執行 —— 刻意不做成 make target
```

機器上還在用、但不想寫進「新機一定要裝」的清單 → 放進 `Brewfile.unmanaged`，
`make prune` 就不會建議刪它。收錄原則與移除紀錄見 [`INVENTORY.md`](INVENTORY.md)。

### 加 zsh plugin

只改 `.chezmoidata.yaml`。兩件事要注意：

1. **plugin 只給補完和 alias，不會幫你裝 binary。** 像 `fzf` 這種，`Brewfile` 也要有一行。
2. **先確認 upstream 現在還有那個 plugin。** oh-my-zsh 會移除 plugin
   （`ripgrep` / `fd` 就被移掉了），列了不存在的 plugin 會讓每次開 shell 都印
   `plugin 'x' not found`。查法：
   `tar -tzf <cached archive> | grep "^ohmyzsh-master/plugins/<name>/$"`，
   或直接看 GitHub 上的 `plugins/` 目錄。

`.zshrc` 的 `plugins=()` 和 `.chezmoiexternal` 的下載清單
都從那一份產生，不會出現「加了 plugin 卻忘了讓 chezmoi 抓下來」。

---

## 2. 改設定 → 進版控

```bash
chezmoi edit ~/.zshrc      # 編輯 source 檔（不是直接改 ~/.zshrc）
chezmoi diff               # 看會改什麼
make quick                 # 套用
cd $(chezmoi source-path) && git add -A && git commit && git push
```

如果是直接改了 `~/.zshrc` 才想起來要進版控：

```bash
chezmoi re-add ~/.zshrc    # 把實體檔案的變更吸回 source
```

**`re-add` 只在主力機做。** 兩台都 re-add + push 就會開始打架。

### 新增檔案到 chezmoi

```bash
chezmoi add ~/.foo
chezmoi add --autotemplate ~/.foo   # 需要跨機器變動時
```

加之前先想：**這個檔案裡有 secret 嗎？** 有的話不要 add，走 Bitwarden
（`make secrets-save`）。pre-commit hook 會擋，但別依賴它 —— 它是最後一道，不是第一道。

### 其他電腦怎麼抓最新版

```bash
make pull                  # = chezmoi update = git pull + apply
```

謹慎一點的版本：

```bash
chezmoi git pull -- --rebase
chezmoi diff               # 先看
chezmoi apply
```

**紀律：主力機是唯一的 source of truth。** 備援機只 `make pull`，不 re-add、不 push。

如果 `.chezmoi.toml.tmpl` 有變動（例如新增了 prompt 問題），chezmoi 會提示
`config file template has changed`，這時要跑一次 `chezmoi init` 重新產生 config。

---

## 3. 新機完整流程

三段，中間可以停下來做別的事。

**① 系統底座**（約 10 分鐘，大部分在等下載）

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Homebrew 一定要先裝，因為 `run_onchange_after_10-brew.sh` 需要它。

**② chezmoi**（一行）

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply --source=~/personal/dotfiles rammusxu
```

這一行做完的事：clone public repo（**匿名 HTTPS，不需要任何憑證**）→ 問 `role` 與
公司 git 身分 → 抓 oh-my-zsh / p10k → 寫 dotfiles → 跑 brew bundle → 裝 gcloud →
設 git hooks → 印出待辦清單。

用 `curl` 而不是 `brew install chezmoi`：新機或 Linux 都是同一行，不用分歧。

**③ 補憑證**（chezmoi 管不到的）

```bash
export BW_SESSION=$(bw unlock --raw)
~/personal/dotfiles/scripts/secrets-restore.sh   # ~/.zshenv

gh auth login        # 選 HTTPS
gh auth setup-git

ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_work -C "$(git -C ~/workspace config user.email)"
gh ssh-key add ~/.ssh/id_ed25519_work.pub
```

第 ② 步結束時終端機會印出這份清單，缺什麼一目瞭然。**它只印不失敗** ——
bootstrap 不該因為少一個 secret 就整個中斷。

---

## 4. 這些機制怎麼運作

### brew 只在 Brewfile 真的變了才重跑

**有，而且實測驗證過。**

機制是 `run_onchange_` 前綴：chezmoi 把 script **render 之後的內容**做 hash 存進
persistent state，內容沒變就整支跳過。所以 script 開頭那幾行是關鍵：

```bash
# Brewfile     hash: {{ include "Brewfile"     | sha256sum }}
# Brewfile.gui hash: {{ include "Brewfile.gui" | sha256sum }}
```

Brewfile 改一個字元 → hash 變 → script 內容變 → chezmoi 重跑。

實測（chezmoi v2.66.1，四次 apply）：

| 動作 | brew bundle 累計執行次數 |
|---|---|
| apply #1（首次） | 1 |
| apply #2（什麼都沒改） | 1 |
| apply #3（什麼都沒改） | 1 |
| 改 Brewfile 後 apply #4 | 2 |

**這是舊版真實存在的 bug**：原本的 `run_onchange_brew-bundle.sh.tmpl` 沒有這幾行 hash，
render 結果永遠一樣，所以改 Brewfile **從來不會**觸發重跑。新機第一次 apply 沒事
（本來就會跑一次），之後兩台再也同步不了套件。

同理 `run_once_after_30-install-gcloud.sh` 用 `run_once_`：一台機器一輩子只跑一次。

### 為什麼 apply 這麼快（以及變慢時怎麼查）

apply 的成本幾乎全在 **externals**（oh-my-zsh 那一坨），不在 dotfiles 本身。
三層優化，由上往下效果遞減：

**① 日常用 `make quick`**

```bash
make quick     # chezmoi apply --exclude=externals
```

完全跳過 externals 的比對。改 `.zshrc`、`.gitconfig`、Brewfile 時用這個就夠了 ——
那些檔案跟 oh-my-zsh 無關。

**② externals 只抓用得到的 plugin**

oh-my-zsh 有 300+ 個 plugin。全抓等於讓 chezmoi 每次 apply 都比對上千個檔案，
而實際用到的只有 `.chezmoidata.yaml` 裡列的那幾個。

所以 `.chezmoiexternal.toml.tmpl` 用 `include` 過濾，清單從 `.chezmoidata.yaml`
產生 —— **同一份清單也產生 `.zshrc` 的 `plugins=()`**，不會出現「加了 plugin
卻忘了讓 chezmoi 抓下來」。要加 plugin 只改 `.chezmoidata.yaml` 一個檔案。

> `include` 的 pattern 有兩個坑（都實測過）：
> 1. 比對的是**壓縮檔裡的原始路徑**，也就是 `stripComponents` 生效【之前】的名字，
>    所以要帶 `ohmyzsh-master/` 前綴。少了前綴 → 一個檔案都不會出來。
> 2. **中間目錄要自己列出來**。只寫 `plugins/git/**` 而沒寫 `plugins` 和 `plugins/git`，
>    chezmoi 會在建目錄時失敗。
>
> `exclude` 也一樣要帶前綴，且必須用 `**`（`themes/*` 這種單層 glob 無效）。

實測(chezmoi v2.66.1,用一份規模接近真實 oh-my-zsh 的壓縮檔):

| | 檔案數 |
|---|---|
| 壓縮檔內總數 | 814 |
| **套用到 `~/.oh-my-zsh` 的數量** | **59** |

只留下 `.chezmoidata.yaml` 列的 9 個 plugin + `lib/` + `tools/`,
themes、templates、其餘 300 個 plugin 全數不落地。
chezmoi 每次 apply 要比對的檔案少了約 93%。

**③ `refreshPeriod` 控制多久才重抓一次**

設 `168h`（一週）。期限內用 cache，不會碰網路。想立刻更新就 `make refresh`。

#### 什麼時候該懷疑「apply 變慢了」

```bash
time chezmoi apply --dry-run
```

如果明顯比 `time make quick` 慢很多，就是 externals 的比對成本 ——
回去看 `.chezmoidata.yaml` 是不是塞了用不到的 plugin。

### oh-my-zsh 為什麼不能開自動更新

`~/.oh-my-zsh` 現在由 chezmoi external 管理，**它不是 git repo**，OMZ 自己的
`omz update` 會失敗。所以 `.zshrc` 裡明確關掉：

```zsh
zstyle ':omz:update' mode disabled
```

更新一律走 `make refresh`。

### 為什麼 ZSH_CUSTOM 不用預設的 `.oh-my-zsh/custom`

因為更新 `.oh-my-zsh` 時整包會被覆蓋掉，放在裡面的東西會消失。改指到 `~/.omz-custom`。

---

## 5. 常見問題

### 兩台機器怎麼同步

**主力機是唯一的 source of truth。**

- 主力機：`chezmoi add` / `re-add` → commit → push
- 備援機：**只** `make pull`，不 re-add、不 push

兩台都往上推，遲早會遇到不想在半夜 debug 的 merge conflict。

### 不小心把 secret commit 了怎麼辦

1. **先當作已經外洩** —— 立刻去把那個 token / key 撤銷重發。這是最重要的一步。
2. 才處理 git 歷史（`git filter-repo`）。但 GitHub 會保留 dangling object，
   force push 不等於刪除。
3. 順序不能反。花兩小時清歷史卻沒撤銷憑證，等於沒做。

### 為什麼這個 repo 是 public

見 [DECISIONS「為什麼這個 repo 是 public」](DECISIONS.md)。一句話：全新的 Mac
沒有任何憑證，只有 public repo 能匿名 clone。

---

## 6. 出事了怎麼查

```bash
make doctor    # 先跑這個：檢查 source-path / chezmoi.toml / ~/.zshenv 有沒有接對
```

| 症狀 | 先看這裡 |
|---|---|
| `chezmoi managed` 是空的、apply 什麼都沒發生 | `make doctor`。幾乎都是 source dir 指到別的 clone，見 [DECISIONS](DECISIONS.md)「為什麼 source dir 設在 ~/personal/dotfiles」 |
| 改了 Brewfile 但 brew bundle 沒跑 | `run_onchange_after_10-brew.sh.tmpl` 開頭的 hash 行還在嗎 |
| plugin 沒載入 / 補完失效 | `.chezmoidata.yaml` 列了，但 `.chezmoiexternal` 沒有對應來源；或該 `make refresh` |
| `git commit` 說不知道你是誰 | 這個 repo 刻意沒有預設 git 身分，見 [DECISIONS](DECISIONS.md)「一台機器兩個身分」 |
| `git push` 認證失敗 / 認成錯的帳號 | `ssh -T git@github.com` 看它回哪個帳號。不帶 alias 的 URL 預設是公司身分；個人 repo 要 `git remote set-url origin git@github-personal:…` |
| 環境變數設了卻沒生效 | 看放對檔案了嗎：secret → `~/.zshenv`；PATH → `~/.zprofile`；alias / 補完 → `~/.zshrc`。三者的差別見 [DECISIONS](DECISIONS.md)「zsh 的設定檔只留三個」 |
| commit 被 pre-commit 擋下 | 訊息會說是哪一類（secret 檔名 / 上游依賴 / pattern / gitleaks）。確定誤判才 `--no-verify` |
| apply 變慢 | [為什麼 apply 這麼快（以及變慢時怎麼查）](#為什麼-apply-這麼快以及變慢時怎麼查) |
| 缺 secret 的東西一直失敗 | `make secrets`（要先 `export BW_SESSION=$(bw unlock --raw)`） |
