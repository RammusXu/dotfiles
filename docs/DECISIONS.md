# 技術決策與 FAQ

這份文件記錄「為什麼是這樣做」。設定檔本身只說明 what，why 放在這裡。

## 三條設計原則

這個 repo 的所有取捨都可以回推到這三條：

1. **剛拿到電腦就能跑。** bootstrap 不能依賴任何憑證 —— 全新的 Mac 沒有 SSH key、
   沒有登入過 gh、沒有解鎖過密碼管理器。任何需要「先設定好某個東西」的方案都不合格。
2. **Secret 結構上不可能進 repo。** 這是 public repo。不是「加密所以應該還好」，
   是「根本沒有 secret 可以外洩」。
3. **身分由目錄決定，不靠記憶。** 公司 / 個人身分靠人手動切，遲早會有一次用錯 email。

---

# Part 1 — 技術選擇

## 為什麼是 chezmoi

| 選項 | 判斷 |
|---|---|
| **chezmoi** | ✅ 採用。多機並存 + template 分流是它的主場；single binary，bootstrap 不需要先裝別的東西 |
| GNU stow / yadm | ❌ 沒有 template。兩台機器的差異化要靠 symlink 手工排列 |
| nix-darwin | ⚠️ 長期一致性大勝（`flake.lock` 是真 lockfile、rollback 一個指令），但學習曲線陡，且 macOS GUI app 是它的弱項 —— 多數人最後還是用 `homebrew.casks` 去驅動 brew，等於多包一層 |
| mackup | ❌ 近幾版 macOS 的 iCloud symlink 已不穩 |

**何時該重新評估 Nix**：機器數 > 3、要跟 CI/容器共用同一份環境定義、
或要替團隊標準化開發環境。兩台機器不值得。

想試的話裝在備援機上 —— 那正好是可以隨便弄壞的實驗場。

## 為什麼用 Homebrew 裝 GUI app

價值不在省下安裝的三分鐘，在於**有一份可描述「這台機器該有什麼」的清單**。

心態要調對：**Brewfile 管的是清單，不是版本。** 它不 pin GUI app 版本，不是 lockfile。

- cask metadata 有 `auto_updates true`（Chrome / VS Code / Obsidian / Linear 都是），
  `brew upgrade --cask` **預設會跳過**，讓 app 自己更新。**不要用 `--greedy` 去接管**，
  那是跟 app 自身更新機制打架的開始。
- **需要 sudo 的 cask 必須從自動化裡拆出來** → `Brewfile.manual`。
  放進 `run_onchange` 會讓新機 bootstrap 卡在密碼提示，這對無人值守的 script 是致命的。
- `version :latest` 的 cask 不驗 checksum，上游改連結時會壞幾天。無解，知道就好。
- `brew bundle` 只裝不移。定期 `brew bundle cleanup --file=Brewfile`（先看 dry-run）。

## 為什麼 Brewfile 拆成三份

| 檔案 | 誰會跑 | 理由 |
|---|---|---|
| `Brewfile` | primary + runner | CLI 工具，背景機也需要 |
| `Brewfile.gui` | 只有 primary | 備援機裝 GUI app 純粹浪費空間 |
| `Brewfile.manual` | **沒有人自動跑** | 需要 sudo / MAS / 非 brew 的東西，只當文件 |

## 為什麼 gcloud 不用 cask

cask 版 `gcloud-cli` **`depends_on python@3.x`**。Homebrew 升 Python minor 版時 gcloud
會跟著壞 —— 這是 macOS 上 gcloud 最常見的故障原因。

官方 versioned archive 自帶 bundled Python，完全解耦。Google 官方文件雖然收錄了 Homebrew
安裝法，但那頁自己標明是 community-maintained cask。

→ `run_once_after_30-install-gcloud.sh.tmpl`，之後更新走 `gcloud components update`。

## 為什麼 oh-my-zsh 不 vendor 進 repo

舊做法是把整包 oh-my-zsh（11MB / 1139 個檔案）commit 進來，更新要手動
`make` 下載 tarball 再 `chezmoi import`。powerlevel10k 甚至連它自己的 `.git` 都被搬進來，
apply 之後會在 `~/.omz-custom/themes/powerlevel10k/` 底下長出一個假的 git repo。

改用 `.chezmoiexternal.toml` 由 chezmoi 直接抓上游，`refreshPeriod = "168h"`。
diff 乾淨了，`git log` 也不再被上游的 commit 淹沒。

## 為什麼 role 用 prompt，不用 hostname

舊的 `.gitconfig` 用 `contains "rammusxu" .chezmoi.hostname` 判斷是不是工作機。
**新機 hostname 一換就靜默切成個人身分** —— 不會報錯，只會用私人 email 往公司 repo commit。

改成 `chezmoi init` 時 `promptStringOnce` / `promptBoolOnce` 問一次，答案存在
`~/.config/chezmoi/chezmoi.toml`。明示優於猜測。

template 裡保留 fallback：舊機還沒重新 init 時，`hasKey` 判斷不到就退回原本的
hostname 邏輯，不會壞。

## 為什麼 source dir 設在 ~/personal/dotfiles

chezmoi 預設把 source dir 放在 `~/.local/share/chezmoi`。那個位置有兩個問題:

1. **不是你會打開來編輯的地方。** 實際上人會另外 clone 一份來改,
   結果同一個 repo 有兩份 clone。
2. **`chezmoi add` / `re-add` 會寫進「執行」那一份**,你在「編輯」那一份看不到。
   兩邊開始漂移,而且是安靜地漂移。

所以 `.chezmoi.toml.tmpl` 用 `sourceDir` 把它指回 `~/personal/dotfiles`,只留一份。

### 代價:bootstrap 一定要帶 `--source`

實測 chezmoi v2.66.1 的行為(兩個方向都試過):

| 指令 | 結果 |
|---|---|
| `chezmoi init --source=~/personal/dotfiles <repo>` | clone 到 `~/personal/dotfiles`,config 產生 `sourceDir`,之後所有指令不用再帶 flag ✅ |
| `chezmoi init <repo>`(忘了帶) | clone 到 `~/.local/share/chezmoi`,但 config 指向 `~/personal/dotfiles`(空的)→ `chezmoi managed` 空白,**且不報錯** ❌ |

`--source` **只在 init 那一次有作用**,它不會被寫進 config —— 所以 `sourceDir` 必須
自己寫在 `.chezmoi.toml.tmpl` 裡。兩者缺一不可。

失敗是靜默的,所以 README 的 bootstrap 指令把 `--source` 標成不可省略。

## 為什麼 dotfiles 放 ~/personal/ 而不是 ~/workspace/

身分規則是 `~/workspace/` → 公司、`~/personal/` → 個人。dotfiles 是 **public 的個人 repo**,
放在 `~/workspace/` 底下就會用公司 email commit 到自己的公開 repo。

一度用 `includeIf` 補例外解決(git 的 includeIf 是後者覆蓋前者):

```gitconfig
[includeIf "gitdir:~/workspace/"]          # 先一律套公司身分
    path = ~/.gitconfig-work
[includeIf "gitdir:~/workspace/dotfiles/"] # 再把個人 repo 挑回來
    path = ~/.gitconfig-personal
```

**但更好的解法是把 repo 搬走。** 例外會累積 —— 每多一個放錯地方的個人專案就多一行,
而且新機 clone 時很容易忘記照抄。搬到 `~/personal/dotfiles` 之後,
一條規則對一個目錄,`dot_gitconfig.tmpl` 裡一個例外都不需要。

規則:**目錄結構決定身分,不要用設定去修補放錯位置的東西。**
真的有個人專案不得不待在 `~/workspace/`,才用上面的 includeIf 補例外。

## Secret 策略：不加密，是根本不放

這是 **public repo**。三個選項：

| 做法 | 問題 |
|---|---|
| 明文進 repo | 不用討論 |
| `encrypted_` + age 加密進 repo | 密文是公開的。金鑰哪天外流 → 所有歷史版本一次回溯解開。而且新機 bootstrap 需要先有金鑰，違反原則 1 |
| **完全不進 repo** ✅ | 結構上不可能洩漏 |

實作：

- `~/.env` 永遠不被 chezmoi 管，`.zshrc` 只是 `[ -f ~/.env ] && source` 它
- 值存在 **Bitwarden 的 Secure Note**（本來就在用的工具，不多養一個）
- 新機第二步：`export BW_SESSION=$(bw unlock --raw) && ./scripts/secrets-restore.sh`
- **bootstrap 不會因為缺 secret 而失敗** —— `run_once_after_40-bootstrap-checklist.sh`
  只印待辦，不 exit 1

再加一層結構性保證：`.githooks/pre-commit` 用 gitleaks + 檔名/pattern 檢查擋提交。
`run_once_after_05` 會自動把 `core.hooksPath` 指過去，所以每台機器都自動生效。

`age` 還是有裝，留給「真的非得進版控的加密檔」那種例外，但預設沒在用。

## SSH 還是 HTTPS

**兩個都還在，沒有誰淘汰誰。** 差別在權限顆粒度：

- **SSH key**：綁整個帳號。一把鑰匙拿到你所有 repo 的權限，**不能設過期**
- **HTTPS + token**：fine-grained PAT 可以指定只給某幾個 repo、只給讀或讀寫、設到期日

以公司環境來說，HTTPS + token 在治理上明顯比較好交代（可稽核、可撤銷、有期限）。

### 但 bootstrap 這一步只能是 HTTPS

這是雞生蛋問題：全新的 Mac 還沒有任何 SSH key，而 key 本身不能放進 public repo。
所以 `chezmoi init --apply rammusxu` 一定要能用 **匿名 HTTPS clone** 完成 ——
這也是這個 repo 必須 public 的真正理由。

之後最省事的預設：

```bash
gh auth login       # 選 HTTPS，走 OAuth，token 存進 keychain
gh auth setup-git   # 讓 git 用 gh 當 credential helper
```

之後 `git clone/push` 都不用再輸入任何東西。

**SSH 還是留著的兩種情況**：需要 SSH commit signing，或公司網路擋 443 以外的東西時反過來用。

### HTTPS clone 為什麼存在

主要是**網路現實**。很多企業防火牆、CI runner、container 只放行 443，SSH 的 22 port
直接被擋。public repo 用 HTTPS 還可以完全免認證 clone，CI 抓依賴很方便。

```bash
git remote set-url origin https://github.com/org/repo.git
```

認證交給 credential helper，**不要手動貼 PAT 到 URL 裡**（會進 `.git/config` 和 shell history）。

## 一台機器兩個身分

關鍵是**用目錄決定身分**，不要靠記憶手動切。

目錄約定：`~/workspace/`（公司）、`~/personal/`（個人）。

**Git 身分** —— `dot_gitconfig.tmpl`：

```gitconfig
[user]
    useConfigOnly = true

[includeIf "gitdir:~/workspace/"]
    path = ~/.gitconfig-work
[includeIf "gitdir:~/personal/"]
    path = ~/.gitconfig-personal
```

`useConfigOnly = true` 是重點：**沒有預設身分**。在沒被 includeIf 覆蓋到的目錄裡 commit
會直接報錯，而不是安靜地用錯的 email 送出去。

> 代價：在 `~/tmp/somerepo` 這種臨時位置 commit 會被擋，要嘛把 repo 放進約定的目錄，
> 要嘛在那個 repo 裡 `git config user.email ...`。這是刻意的摩擦。

**連線身分** —— `private_dot_ssh/private_config.tmpl`：

```
Host github-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_work
    IdentitiesOnly yes
```

remote 寫 `git@github-work:eslitecorp/repo.git`。**用哪把 key 由 remote URL 決定**，
不會兩個帳號互相打架。`IdentitiesOnly yes` 不能省，否則 ssh-agent 會把所有 key
依序試一遍，GitHub 認第一把成功的 —— 那可能不是你要的那把。

**一個要注意的坑**：gh CLI 從 v2.40 起支援同一 host 多帳號，但**沒有做「依 pwd 或 git
remote 自動切換」**。所以 `git push` 會因為 SSH alias 自動用對 key，但 `gh pr create`
還是用「目前 active 的帳號」，要自己 `gh auth switch`。

實務上的解法：在 shell prompt 顯示 active user，或在公司目錄用 direnv 設 `GH_TOKEN`。

## macOS 系統設定：分三層

`defaults` 的 domain 沒有正式文件、跨版本會變。**整包 dump 再 restore 是災難來源**。

| 層級 | 做法 | 例子 |
|---|---|---|
| **script 管** | 穩定、你真的在乎的少數 key | 鍵盤重複速度、Finder 顯示副檔名/路徑列、截圖位置、三指拖移、關掉智慧引號 |
| **手動設一次** | 巢狀 plist 或格式易變 | Dock 排列（`persistent-apps`）、輸入法、通知 |
| **完全不要碰** | 需要 TCC 授權，存在 SIP 保護的資料庫 | 輔助使用、螢幕錄製、完整磁碟取用。defaults 寫不進去 |

還有一層是 **iCloud 已經同步的**：Safari、密碼、桌布。登入 Apple ID 就有。

對抗版本變動的三個機制：每個 key 附 `verified_on` 註解、全部 `|| true`（key 在新版消失
是正常的）、用 `scripts/macos-defaults-dump.sh` 在舊機 dump baseline 當**參考文件**
而不是 apply 來源。

## 已被 macOS 26 取代的第三方 app

| App | 原生狀況 | 判斷 |
|---|---|---|
| **Rectangle** | Sequoia 起內建視窗貼齊，Tahoe 再加並排間距 | 先只用原生兩週。原生涵蓋二/四分割，Rectangle 多的是**三分割**和自訂快捷鍵 |
| **Bitwarden** | 內建 Passwords app 可存密碼、passkey、2FA | **留著**。跨平台、共享保險庫、組織功能是 Passwords 沒有的 |
| **Xnip** | 原生截圖 + 標示 | **留著**。原生仍沒有**捲動截圖**。Homebrew 沒有它（MAS app），要手動裝 |

---

# Part 2 — FAQ

### 新 Mac 怎麼開機？

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply rammusxu
```

用 `curl` 而不是 `brew install chezmoi`：可能是全新機器或 Linux 機器，為了一致性統一用 curl。
（Homebrew 那行還是要先跑，因為 `run_onchange_after_10-brew.sh` 需要它。）

`init` 會問 `role`（primary / runner）和 `isWork`。跑完看終端機印出的 bootstrap 檢查清單。

### 新增 brew 套件？

編輯 `Brewfile`（CLI）或 `Brewfile.gui`（cask），下次 `chezmoi apply` 會自動重跑 brew bundle。

靠的是 `run_onchange_after_10-brew.sh.tmpl` 開頭那幾行 `sha256sum` ——
`run_onchange_` 是比對「script render 後的內容」有沒有變。
**沒有那幾行 hash，改 Brewfile 永遠不會觸發重跑**（這是舊版真實存在的 bug）。

### 新增檔案到 chezmoi？

```bash
chezmoi add ~/.foo
chezmoi add --autotemplate ~/.foo   # 需要跨機器變動時
```

加之前先想：**這個檔案裡有 secret 嗎？** 有的話不要 add，走 Bitwarden。
pre-commit hook 會擋，但別依賴它 —— 它是最後一道，不是第一道。

### 怎麼更新 oh-my-zsh / p10k？

```bash
make refresh    # chezmoi apply --refresh-externals
```

不要開 oh-my-zsh 自己的自動更新。

### 為什麼 ZSH_CUSTOM 不用預設的 `.oh-my-zsh/custom`？

因為更新 `.oh-my-zsh` 時會被整個覆蓋掉。改指到 `~/.omz-custom`。

### apply 之前要做什麼？

```bash
chezmoi diff    # 一定要先看
```

尤其是在舊機上 pull 完之後。

### 兩台機器怎麼同步？

**新機是唯一的 source of truth。**

- 新機：`chezmoi add` / `re-add` → commit → push
- 舊機：**只** `chezmoi update`，不 re-add、不 push

兩台都往上推，遲早會遇到不想在半夜 debug 的 merge conflict。

### 機器上裝的東西跟 Brewfile 對不上？

```bash
make audit    # scripts/brewfile-audit.sh
```

會列出三個差集：機器有但沒宣告的、宣告了但機器沒有的、cask 的差集，
外加佔空間前 15 名。

### 不小心把 secret commit 了怎麼辦？

1. **先當作已經外洩** —— 立刻去把那個 token / key 撤銷重發。這是最重要的一步。
2. 才處理 git 歷史（`git filter-repo`）。但 GitHub 會保留 dangling object，
   force push 不等於刪除。
3. 順序不能反。花兩小時清歷史卻沒撤銷憑證，等於沒做。

### 為什麼這個 repo 是 public？

因為原則 1：全新的 Mac 沒有任何憑證，只有 public repo 能匿名 HTTPS clone。
private repo 會變成「要先設定認證才能設定機器」的循環。

代價是所有內容都必須經得起公開 —— 這反而強迫了乾淨的 secret 邊界。

---

# Part 3 — 日常維運

## Q. 拿到新電腦，完整要跑什麼？

三段，中間可以停下來做別的事。

**① 系統底座**（約 10 分鐘，大部分在等下載）

```bash
xcode-select --install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Homebrew 一定要先裝，因為 `run_onchange_after_10-brew.sh` 需要它。

**② chezmoi**（一行）

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply rammusxu
```

這一行做完的事：clone public repo（**匿名 HTTPS，不需要任何憑證**）→ 問 `role` 與
`isWork` → 抓 oh-my-zsh / p10k → 寫 dotfiles → 跑 brew bundle → 裝 gcloud →
設 git hooks → 印出待辦清單。

用 `curl` 而不是 `brew install chezmoi`：新機或 Linux 都是同一行，不用分歧。

**③ 補憑證**（chezmoi 管不到的）

```bash
export BW_SESSION=$(bw unlock --raw)
~/.local/share/chezmoi/scripts/secrets-restore.sh   # ~/.env

gh auth login        # 選 HTTPS
gh auth setup-git

ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_work -C 'rammusxu@eslite.com'
gh ssh-key add ~/.ssh/id_ed25519_work.pub
```

第 ② 步結束時終端機會印出這份清單，缺什麼一目瞭然。**它只印不失敗** ——
bootstrap 不該因為少一個 secret 就整個中斷。

## Q. 改了設定之後怎麼更新？

```bash
chezmoi edit ~/.zshrc      # 編輯 source 檔（不是直接改 ~/.zshrc）
chezmoi diff               # 看會改什麼
chezmoi apply
cd $(chezmoi source-path) && git add -A && git commit && git push
```

如果是直接改了 `~/.zshrc` 才想起來要進版控：

```bash
chezmoi re-add ~/.zshrc    # 把實體檔案的變更吸回 source
```

**`re-add` 只在主力機做。** 兩台都 re-add + push 就會開始打架。

## Q. 其他電腦怎麼抓最新版？

```bash
chezmoi update             # = git pull + apply，一個指令
```

謹慎一點的版本：

```bash
chezmoi git pull -- --rebase
chezmoi diff               # 先看
chezmoi apply
```

**紀律：主力機是唯一的 source of truth。** 備援機只 `chezmoi update`，不 re-add、不 push。

如果 `.chezmoi.toml.tmpl` 有變動（例如新增了 prompt 問題），chezmoi 會提示
`config file template has changed`，這時要跑一次 `chezmoi init` 重新產生 config。

## Q. brew 有確保「只在變更時才套用」嗎？

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

## Q. 怎麼讓每次 apply 都很快？

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

### 什麼時候該懷疑「apply 變慢了」

```bash
time chezmoi apply --dry-run
```

如果明顯比 `time make quick` 慢很多，就是 externals 的比對成本 ——
回去看 `.chezmoidata.yaml` 是不是塞了用不到的 plugin。

## Q. oh-my-zsh 為什麼不能開自動更新？

`~/.oh-my-zsh` 現在由 chezmoi external 管理，**它不是 git repo**，OMZ 自己的
`omz update` 會失敗。所以 `.zshrc` 裡明確關掉：

```zsh
zstyle ':omz:update' mode disabled
```

更新一律走 `make refresh`。
