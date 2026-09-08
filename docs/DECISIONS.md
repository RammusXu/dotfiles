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

## 為什麼 chezmoi 自己不用 brew 裝

chezmoi 是**唯一**不在 Brewfile 裡的工具，用 `curl | sh` 裝進 `~/bin`。

因為它是 bootstrap 的第一步：Brewfile 是 chezmoi **管的東西**，chezmoi 不能反過來
依賴它。而且同一行在 macOS 和 Linux 都能跑，新機流程不用分歧。

### 代價：`-b ~/bin` 也不能省

`get.chezmoi.io` 的 installer 預設裝到**當下工作目錄的 `./bin`**（不是 `~/bin`，
也不是任何 PATH 上的位置）。站在 `$HOME` 跑剛好對，站在別的地方跑就錯 ——
而且當下不會有任何抱怨，binary 確實裝好了，只是在一個沒人會找的地方。

2026-09-08 真的踩到：在 `~/work/playground-tmp/` 跑 bootstrap，binary 進了
`~/work/playground-tmp/bin/chezmoi`。config 和 clone 都是好的，隔天 `make apply`
只吐一句 `make: chezmoi: No such file or directory`，看不出跟工作目錄有關。

所以 bootstrap 指令固定帶 `-b ~/bin`，`make doctor` 也會檢查 binary 的位置。
這跟 `--source` 是同一類毛病：**預設值是相對於「你當下在哪」而不是「你要什麼」**，
失敗又是靜默的。凡是這種，就把它明示在指令裡。

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

### install.sh 的兩個 flag 都要 false

```
--path-update false --command-completion false
```

gcloud 的 `install.sh` 預設會**直接 append 幾行到 `~/.zshrc`**。這裡的 rc 檔全部由
chezmoi 管，所以那幾行的下場是：不在版控裡 → 下次 apply 被還原掉 → 補完安靜消失。
而這支是 `run_once_`，不會再跑第二次來補回去。

2026-09-08 就是這樣掉的：`~/.zshrc` 尾巴多了一行 gcloud 補完，`chezmoi diff` 顯示
下次 apply 會刪掉它。改成兩個 flag 都 false，兩件事各自進版控：

| | 由誰負責 |
|---|---|
| PATH（`path.zsh.inc`） | `dot_zprofile.tmpl` |
| 補完（`completion.zsh.inc`） | `dot_zshrc.tmpl` |

**通則：任何第三方 installer 都不准碰 rc 檔。** 一律關掉它的 rc-writing flag，
自己在 template 裡寫一行 guard 過的 `source`。

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

**為什麼不直接寫進 `~/.zshenv`。** 那是最方便的做法，也是錯的 —— `~/.zshenv` 整
檔就是 Bitwarden 那顆 Secure Note 的內容（`secrets-restore.sh` 是 `bw get notes >
~/.zshenv`，**整檔覆蓋**；`secrets-backup.sh` 反過來把整檔寫回 note）。把「只有
這台機器要」的設定加進去，等於宣告它要同步到**每一台**機器 —— 這正好是這類設定
不該有的性質。而且哪台機器最後跑 `make secrets-save`，note 就長它的樣子，其他機器
下次 restore 就被覆蓋掉，沒有任何錯誤訊息。`~/.zshenv` 該只放 secret，一種東西一個家。

> 2026-09 之前 `secrets-backup.sh` 是印指示叫你手動貼進 GUI，那時的失敗模式是
> 「加進去的東西根本沒進 Bitwarden，換機就無聲消失」。改成自動寫入之後失敗模式
> 換了個方向（變成無聲同步到每台機器），結論沒變。

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

**日常 git 走 SSH，HTTPS 只留給 bootstrap 的匿名 clone。** 2026-09-08 定案；在那之前
是反過來的（預設 HTTPS + `gh auth setup-git`）。改掉的兩個理由都來自同一件事：
一台機器上有兩個 GitHub 帳號。

### 理由一：HTTPS 沒辦法讓身分跟著目錄走

`gh` 從 v2.40 起同一個 host 可以登入多個帳號，但它當 credential helper 時
**只認「目前 active 的那一個」** —— 不看 pwd，也不看 remote URL。走 HTTPS 的話，
`~/personal/` 底下 push 出去的身分，取決於你上次 `gh auth switch` 切到哪。

SSH 沒有這個問題：remote 寫成 `git@github-personal:…`，`~/.ssh/config` 就把 key 釘死了。
**身分由 remote URL 決定，不由「我記不記得切帳號」決定** —— 跟 `.gitconfig` 用
`includeIf` 拿目錄決定 commit 身分是同一套思路。

### 理由二：`gh auth setup-git` 會寫進 chezmoi 管的檔案

它把這幾行 append 到 `~/.gitconfig`：

```gitconfig
[credential "https://github.com"]
	helper =
	helper = !/opt/homebrew/bin/gh auth git-credential
```

而 `~/.gitconfig` 是 chezmoi 管的，這幾行不在 `dot_gitconfig.tmpl` 裡 ——
**下次 `make apply` 會整段刪掉，而且不會有任何警告**。症狀是某天 push 突然開始要帳密。
2026-09-08 用 `chezmoi diff ~/.gitconfig` 實測確認過。

這跟 gcloud `install.sh` 是同一個坑，[通則也一樣](#installsh-的兩個-flag-都要-false)：
任何第三方 installer 都不准碰 chezmoi 管的檔案。gcloud 的解法是關掉它的 flag、自己在
template 裡寫一行；`gh` 的解法更乾脆 —— **走 SSH 就根本不需要這個 helper**。

### 代價：SSH key 的權限顆粒度比較差

這點沒有被解決，只是被接受：

- **SSH key**：綁整個帳號、一把拿到所有 repo、**不能設過期**
- **HTTPS + fine-grained PAT**：可指定 repo、可指定唯讀、可設到期日

單看治理，HTTPS + PAT 明顯好交代（可稽核、可撤銷、有期限）。這裡仍然選 SSH，是因為
「用錯帳號 push 出去」是每天都可能發生的事，而「key 沒有到期日」要缺乏輪替紀律才會咬人。
兩害相權先解天天會踩的那個。緩解：key 只留在本機（換機產新的、舊 key 留在舊機各自撤銷），
repo 層級的權限交給 org 那邊控。

### bootstrap 那一步仍然只能是 HTTPS

雞生蛋問題沒變：全新的 Mac 還沒有任何 SSH key，而 key 不能放進 public repo。所以
`chezmoi init --apply rammusxu` 一定要能用**匿名 HTTPS clone** 完成 ——
這也是這個 repo 必須 public 的真正理由。

clone 完、key 產出來之後，把 source dir 自己的 remote 換過去：

```bash
git -C ~/personal/dotfiles remote set-url origin git@github-personal:rammusxu/dotfiles.git
```

`run_once_after_40` 會檢查這件事，沒換過就每次都印待辦。

HTTPS 還留著一個場景：企業防火牆、CI runner、container 常常只放行 443，SSH 的 22 port
直接被擋，那種環境反過來用 HTTPS + PAT。**但不要把 PAT 貼進 URL**
（會進 `.git/config` 和 shell history），交給 credential helper。

### gh 只給公司帳號用

**個人帳號不掛在 gh 上。** 原本想的是兩個帳號都 `gh auth login`、要用時 `gh auth switch`，
2026-09-08 真的要動手時放棄了：

- 這台機器的個人帳號**只需要 push / pull**，而那走 SSH，跟 gh 一點關係都沒有。
  要開 PR、查 issue、打 API 的都是公司 repo。為了用不到的功能，在個人帳號上多掛一個
  長期有效的 OAuth token，不划算。
- `gh` 沒有「依 pwd 或 remote 自動切帳號」的能力。多登一個帳號就是多一個失敗模式，
  而它的症狀（`gh pr create` 開在錯的帳號底下）通常**事後才會發現**。
- 少一個帳號，`gh ssh-key add` 把公鑰傳到錯帳號的坑也一起消失。

| | 公司帳號 | 個人帳號 |
|---|---|---|
| 認證 | `gh auth login -h github.com -p ssh -w`（瀏覽器 OAuth） | **不登入 gh** |
| 上傳公鑰 | `gh ssh-key add ~/.ssh/<work>.pub` | `pbcopy` 貼進 github.com/settings/ssh/new |
| git push | SSH（`github.com` 預設 alias） | SSH（`github-personal` alias） |
| PR / issue / API | `gh` | 瀏覽器 |

`gh auth setup-git` 兩邊都不要跑，理由見「理由二」。

登入一律帶 `-w` 走瀏覽器。2026-09-08 試過選 "Paste an authentication token" 貼一把舊 PAT，
拿到 `HTTP 401: Bad credentials` —— OAuth 沒有自己管 PAT 到期這回事。

## 一台機器兩個身分

**這裡是兩套機制，判斷依據不一樣。混為一談是最常見的誤解**（2026-09-08 自己就搞混過一次，
以為「反正身分是目錄決定的」，結果漏掉了 remote URL 那一半）：

| | 決定什麼 | 依據什麼 | 設定在哪 |
|---|---|---|---|
| `includeIf` | **commit 身分**（作者 name / email） | **目錄** | `.gitconfig` |
| `~/.ssh/config` | **認證身分**（push 時用哪把 key） | **remote URL 的 host** | `.ssh/config` |

`ssh` 完全不知道你站在哪個目錄，它只拿 URL 裡的 host 字串去查表。所以「人在
`~/personal/` 底下，但 remote 寫 `git@github.com:…`」的下場是
**commit 署名個人、認證卻用公司 key** —— 兩半各對一半。當場驗證：

```bash
cd ~/personal/some-repo
git config user.email                            # commit 身分：看目錄
ssh -G git@github.com | grep '^identityfile'     # 認證身分：看 host，跟 cwd 無關
```

兩套要達成的事是同一件：**不要靠記憶手動切**。目錄約定 `~/workspace/`（公司）、
`~/personal/`（個人）。

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

### key 由 script 產，上傳永遠手動

2026-09-08 之前這裡寫的是「這個 repo 不產生也不碰任何 key，只把 `ssh-keygen` 指令印出來」。
翻案的理由：換機要做三件事 —— 產 key → 上傳公鑰 → 換 remote —— 其中只有第一件是
**完全機械、沒有任何決策、也沒有外部副作用**的，偏偏它又是後面兩件的前置。
留給人做，實際效果只是每次換機多一道複製貼上的儀式。

`run_once_after_35-ssh-keys.sh.tmpl` 負責產，界線畫得很死：

- **只在檔案不存在時產**（每一把都先 `[ -f ]` 擋過）。既有的 key 一根寒毛都不會動 ——
  這是原本那條規則裡真正重要的部分，完整保留。
- **ed25519、`-N ""` 無 passphrase**，比照這台機器既有的慣例（key 只留本機，靠 FileVault 保護）。
- **私鑰永遠不進版控、不上傳、不備份進 Bitwarden。** 換機產新的，舊 key 留在舊機各自撤銷。

**上傳沒有自動化**，因為那一步會動到 GitHub 帳號（外部副作用、要選帳號、要決定 key 標題），
而且公司走 gh、個人走 web UI 是兩套流程。`run_once_after_40` 改用 `ssh -T` 檢查
**「GitHub 那邊認不認得這把 key」**，沒過就印出對應那一套的指令。這比檢查檔案在不在有用 ——
一次 `ssh -T` 同時驗了 key 存在、公鑰已上傳、`~/.ssh/config` 的 alias 指對了三件事。

會被 apply 整份覆蓋的只有 `~/.ssh/config` 本身 —— 手改過的內容要先搬進 template。

gh CLI 為什麼只登入公司帳號，見上面 [gh 只給公司帳號用](#gh-只給公司帳號用)。

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
