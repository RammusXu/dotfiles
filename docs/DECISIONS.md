# 技術決策

這份文件只回答一件事：**為什麼是這樣做**。設定檔本身說明 what，why 在這裡。

想知道「怎麼做」（更新套件、換機、apply 流程、出事怎麼查）看
[`RUNBOOK.md`](RUNBOOK.md)。想知道「裝了什麼、為什麼不裝別的」看
[`INVENTORY.md`](INVENTORY.md)。

## 三條設計原則

這個 repo 的所有取捨都可以回推到這三條：

1. **剛拿到電腦就能跑。** bootstrap 不能依賴任何憑證 —— 全新的 Mac 沒有 SSH key、
   沒有登入過 gh、沒有解鎖過密碼管理器。任何需要「先設定好某個東西」的方案都不合格。
2. **Secret 結構上不可能進 repo。** 這是 public repo。不是「加密所以應該還好」，
   是「根本沒有 secret 可以外洩」。
3. **身分由目錄決定，不靠記憶。** 公司 / 個人身分靠人手動切，遲早會有一次用錯 email。

---

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

## zsh 的設定檔只留三個

zsh 自己就有明確的分工，照它的規則走就不需要自訂的載入層：

| 檔案 | 什麼時候讀 | 放什麼 |
|---|---|---|
| `~/.zshenv` | **每個** shell，最早（連 `zsh -c` 都會） | secret / token，不進版控 |
| `~/.zprofile` | 登入 shell | PATH、環境變數 |
| `~/.zshrc` | 互動式 shell | oh-my-zsh、plugin、alias、函式、補完、prompt |

2026-09 之前是這樣的：`~/.zshrc` → source `~/.common_env` → source `~/.env` +
`~/.bash_alias`，而 `~/.bashrc` 存在的唯一理由就是也去 source `~/.common_env`
（為了讓 bash 也吃得到）。

砍掉那兩層的理由：

1. **實際上只用 zsh。** 為了假想的 bash 使用者多維護一層抽象，代價是每次要改東西
   都得先想「這該放哪個檔」。macOS 內建的 bash 還是 3.2（2007 年），不會拿來當日常 shell。
2. **`~/.env` 不是慣例。** zsh 本來就會自動讀 `~/.zshenv`，而且比 `.zshrc` 更早、
   非互動式也讀得到。自訂一個 `~/.env` 再手動 source，等於重新實作一個已經存在的機制，
   還多一個「忘記 source 就靜靜失效」的失敗模式。
3. **PATH 放 `.zprofile` 才是 macOS 的慣例。** Homebrew 官方安裝說明就是叫你把
   `brew shellenv` 寫進 `~/.zprofile`。

舊檔（`.common_env` / `.bash_alias` / `.bashrc`）由 `.chezmoiremove` 在 apply 時
自動從 `$HOME` 清掉，不需要每台機器手動處理。**`~/.env` 刻意沒有列進去** ——
那是 secret，讓 script 自動刪一個可能還沒備份的檔案太危險。

### 但留了一個出口：`~/.zprofile.local`

上面三個檔案都進版控，所以裡面的東西每台機器都會拿到。但有一類設定不符合這個
前提：**只有這台機器需要、卻又不是 secret**。例如公司網路的 TLS 中間人 CA 憑證
路徑、某個客戶的 VPN 設定、暫時性的實驗。

`~/.zprofile` 的最後一行因此是：

```bash
[ -f "$HOME/.zprofile.local" ] && source "$HOME/.zprofile.local"
```

**為什麼不直接寫進 `~/.zshenv`。** 那是最方便的做法，也是錯的 —— `~/.zshenv` 是
Bitwarden 的還原目標，而兩個方向不對稱：

- `secrets-restore.sh` 是 `bw get notes > ~/.zshenv`，**整檔覆蓋**
- `secrets-backup.sh` 是**手動**貼進 Bitwarden GUI（刻意的，見 Secret 策略那節）

所以加在 `~/.zshenv` 的非 secret 設定不會自動進 Bitwarden，下次換機或還原時就
**無聲消失**，沒有任何錯誤訊息。`~/.zshenv` 該只放 secret，一種東西一個家。

**為什麼「有這個出口」這件事要進版控。** 出口裡的內容不進版控，但那一行 source
進。這樣換機時看 `~/.zprofile` 就知道還有一個本機檔案要補，而不是三個月後對著一個
沒生效的設定發呆。這是「靜靜失效」那個失敗模式的同一個解法。

**代價：它沒有備份。** 不在 git、不在 Bitwarden。所以它只適合放「掉了重寫一行就好」
的東西；重建不出來的設定該進版控或進 Bitwarden，不該待在這裡。

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

- `~/.zshenv` 永遠不被 chezmoi 管。用 `~/.zshenv` 而不是自訂的 `~/.env`：這是 zsh 的
  慣例位置 —— zsh 每個 shell 啟動時、比 `.zshrc` 更早自動讀它，連 `zsh -c` 這種
  非互動式呼叫都吃得到，所以 `.zshrc` 完全不用碰。bash 沒有這個機制，由
  `~/.common_env` 用 `[ -z "$ZSH_VERSION" ]` 判斷後補讀一次
- 值存在 **Bitwarden 的 Secure Note**（本來就在用的工具，不多養一個）
- 新機第二步：`export BW_SESSION=$(bw unlock --raw) && ./scripts/secrets-restore.sh`
- **bootstrap 不會因為缺 secret 而失敗** —— `run_once_after_40-bootstrap-checklist.sh`
  只印待辦，不 exit 1

再加一層結構性保證：`.githooks/pre-commit` 用 gitleaks + 檔名/pattern 檢查擋提交。
`run_once_after_05` 會自動把 `core.hooksPath` 指過去，所以每台機器都自動生效。

`age` 刻意**沒有**裝。它本來是留給「真的非得加密進版控的例外」，但那個例外
從來沒發生過 —— 需要的那天再 `brew install age`，不需要為了一個假設的例外
在每台機器上多帶一個工具（見 [INVENTORY](INVENTORY.md)）。

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

公司的 name / email 不寫死在這個 public repo 裡 —— `dot_gitconfig-work.tmpl` 從
`~/.config/chezmoi/chezmoi.toml` 讀 init 時問的 `workName` / `workEmail`。要改就重跑
`chezmoi init`。（沒重新 init 過的舊機器會 fallback 成佔位字串 `you@company.com`，
bootstrap 檢查清單會抓到，不會安靜地用錯身分。）

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

remote 寫 `git@github-work:your-company-org/repo.git`。**用哪把 key 由 remote URL 決定**，
不會兩個帳號互相打架。`IdentitiesOnly yes` 不能省，否則 ssh-agent 會把所有 key
依序試一遍，GitHub 認第一把成功的 —— 那可能不是你要的那把。

**但不能只有 alias。** 2026-09 盤點時發現一件事：26 個 repo 裡有 25 個的 remote 是
`git@github.com:…` 這種不帶 alias 的 URL，其中 20 個是公司 repo。如果 `~/.ssh/config`
裡只有 alias，那些 repo 全部會掉到 `Host *`（沒有 `IdentityFile`）—— push 能不能成功
就看 ssh-agent 裡剛好有哪把 key。所以 config 裡明確保留 `Host github.com` /
`Host gitlab.com`，**預設走公司身分**（因為多數是公司 repo）。

代價：個人 repo 若用不帶 alias 的 URL 會拿公司 key 去認證。所以個人 repo 一律
`git remote set-url origin git@github-personal:…`。這是刻意選的預設值 ——
把「忘記設 alias」的後果放在比較少的那一邊。

**key 的檔名不寫進這個 public repo。** template 用 `sshKeyWork` /
`sshKeyWorkGitlab` / `sshKeyPersonal` 三個值，預設是慣例名稱
（`id_ed25519_work` / `id_ed25519_personal`），舊機器 key 名字不一樣的話在
`~/.config/chezmoi/chezmoi.toml` 覆寫。理由跟 git 身分一樣：檔名可能帶公司名。

**這個 repo 不產生也不碰任何 key。** 整包沒有一處執行 `ssh-keygen`（bootstrap
檢查清單只是把指令印出來）。會被覆蓋的只有 `~/.ssh/config` 本身 —— 手改過的內容
要先搬進 template。

**一個要注意的坑**：gh CLI 從 v2.40 起支援同一 host 多帳號，但**沒有做「依 pwd 或 git
remote 自動切換」**。所以 `git push` 會因為 SSH alias 自動用對 key，但 `gh pr create`
還是用「目前 active 的帳號」，要自己 `gh auth switch`。

實務上的解法：在 shell prompt 顯示 active user，或在公司目錄用 direnv 設 `GH_TOKEN`。

## macOS 系統設定：不進版控

**這個 repo 不管 macOS 系統偏好。** 系統設定改到哪就是哪，不記錄、不還原、不強制。

2026-09 之前有一個 `run_onchange_after_20-macos-defaults.sh.tmpl`，用 `defaults write`
管 16 個 key（鍵盤重複速度、Finder 顯示副檔名/路徑列、截圖位置、三指拖移、關掉智慧引號）。
整段移除了。

### 為什麼移除

原本設計了三個機制來對抗「`defaults` 的 domain 沒有正式文件、跨版本會變」這個問題。
review 的時候一個一個查，三個裡有兩個是假的：

**1. `verified_on` 註解 —— 填的是沒發生過的事。**
檔頭寫 `verified_on: macOS 26 (Tahoe)`，但實際上：機器是 macOS 15.3、`chezmoi state dump`
的 `scriptState` 裡**沒有這個 script 的紀錄**（從來沒執行過）、16 個 key 有 11 個是
`<未設定>`，而 `NSAutomaticCapitalizationEnabled` 還是 `1`（跟意圖正好相反）。
一個沒被執行過的 script 帶著「已驗證」的註解，比沒有註解更危險。

**2. 全部 `|| true` —— 防的是不存在的失敗模式。**
`defaults write` 對「macOS 已經移除的 key」**不會失敗**。實測寫一個完全虛構的
domain + 虛構 key，`rc=0`，而且值真的寫進去了 —— `defaults` 只是在寫 plist，
它不驗證 key 有沒有意義。唯一會回非 0 的是 domain 不可寫。

所以 key 在新版消失時，得到的不是「apply 失敗」而是**無聲的無效寫入**，`|| true`
讓它更無聲。打錯字更慘：`defaults write NSGlobalDomain KeyRepeat -badtype` 回 `rc=0`，
並且把 integer 2 寫成字串 `"-badtype"`。`|| true` 在這裡沒有任何保護作用。

**3. `scripts/macos-defaults-dump.sh` 當參考文件 —— 這個是真的有用，留著。**

### 為什麼不是「修好它」而是「移除」

要讓 script 真的可靠，得為每個 key 加「寫入後讀回驗證」。但即使加了也只能證明
**值寫對了**，不能證明**設定生效了** —— 三指拖移這類 key 要登出重入才作用，
讀回驗證會通過而手勢還是沒反應。也就是說投入維護成本之後，得到的仍然不是保證。

而對面的成本很低：這 16 個設定在「系統設定」裡點一遍大約 5 分鐘，**一台機器一輩子只做一次**。
拿 5 分鐘換一個需要每次 macOS 大版本更新都重驗、而且驗不完全的 script，不划算。

這跟 Dock 排列當初被排除的理由是同一個，只是把那條線往外移了：**換新機本來就該重新想一次
這些設定要什麼**，把它凍結在版控裡反而是在保存兩年前的偏好。

### 那現在怎麼辦

- 新機的手動待辦列在 `README.md` 的「換機待辦」和 `run_once_after_40-bootstrap-checklist.sh`
- 換機前在舊機跑 `scripts/macos-defaults-dump.sh`，dump 出來當**對照表**，照著在新機點一遍
- **需要 TCC 授權的東西本來就只能手動**：輔助使用、螢幕錄製、完整磁碟取用存在 SIP
  保護的資料庫裡，`defaults` 寫不進去，硬寫只會壞掉
- **iCloud 已經同步的不用管**：Safari、密碼、桌布，登入 Apple ID 就有

## 已被 macOS 26 取代的第三方 app

| App | 原生狀況 | 判斷 |
|---|---|---|
| **Rectangle** | Sequoia 起內建視窗貼齊，Tahoe 再加並排間距 | 先只用原生兩週。原生涵蓋二/四分割，Rectangle 多的是**三分割**和自訂快捷鍵 |
| **Bitwarden** | 內建 Passwords app 可存密碼、passkey、2FA | **留著**。跨平台、共享保險庫、組織功能是 Passwords 沒有的 |
| **Xnip** | 原生截圖 + 標示 | **留著**。原生仍沒有**捲動截圖**。Homebrew 沒有它（MAS app），要手動裝 |

---
