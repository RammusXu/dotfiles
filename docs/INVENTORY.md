# Inventory — 裝了什麼、為什麼不裝別的

這份文件回答「這台機器上到底該有什麼」。清單本身在 `Brewfile*` 和 `.chezmoidata.yaml`，
這裡記的是**收錄原則**和**移除紀錄** —— 免得半年後看到 Brewfile 少了某個東西，
想不起來是刻意移掉還是不小心弄掉的。

## 五份清單，各管一件事

| 檔案 | 誰會讀 | 內容 |
|---|---|---|
| `Brewfile` | `brew bundle`（每次 apply） | CLI 工具。primary 和 runner 都裝 |
| `Brewfile.gui` | `brew bundle`（只有 role=primary） | GUI cask。每項標注 tap 與 binary 來源 |
| `Brewfile.manual` | **人** | 需要 sudo / MAS / 非 brew 的東西。不會自動執行 |
| `Brewfile.unmanaged` | 只有 `scripts/brew-prune.sh` | 機器上刻意留著、但不進「新機要裝」的清單 |
| `.chezmoidata.yaml` | chezmoi template | zsh plugin 清單（見下） |

`Brewfile.unmanaged` 存在的理由：從 `Brewfile` 拿掉一行只代表「不再管理」，
不代表「要從這台機器刪掉」。沒有這份清單，`make prune` 會建議你把天天在用的
終端機 uninstall 掉。

## 收錄原則

一個東西要留在 `Brewfile`，至少符合一條：

1. **近 12 個月有使用痕跡** —— shell history，或 `~/.<tool>/` 這類 config 目錄的 mtime
2. **這套 dotfiles 自己要用** —— `gitleaks`（pre-commit）、`bitwarden-cli`（secrets）
3. **某個留下來的東西依賴它** —— 例如 `fzf` / `zoxide` 是對應 omz plugin 的前提

都不符合就移出去。**移出不等於解除安裝**，需要時 `brew install` 一秒就回來；
真正的成本是「一份沒人敢動的清單」——每次換機都把不確定的東西再帶到下一台。

判斷的時候不要只看 shell history：像 `terraform` 在 history 裡是 0 筆，
但 `~/.terraform.d/` 上個月才動過。兩種證據都要看。

## zsh plugin：只有清單，沒有內容

**oh-my-zsh、powerlevel10k、zsh plugin 的內容一個字都不在這個 repo 裡。**

- **要哪些** → `.chezmoidata.yaml`（`omzPlugins` / `customPlugins`）
- **從哪裡抓** → `.chezmoiexternal.toml.tmpl`
- **怎麼載入** → `.zshrc` 的 `plugins=()`，同樣由 `.chezmoidata.yaml` 產生

同一份清單同時決定「抓什麼」和「載什麼」，所以不會出現「加了 plugin 卻忘了讓
chezmoi 抓下來」。加 plugin 只改 `.chezmoidata.yaml` 一個檔。

為什麼不 vendor 進 repo：見 [DECISIONS](DECISIONS.md)「為什麼 oh-my-zsh 不 vendor 進 repo」。
兩層防手滑：`.gitignore` 擋 `dot_oh-my-zsh/` `dot_omz-custom/`，
`.githooks/pre-commit` 擋任何看起來像上游內容的 staged 檔案。

`chezmoi` 的 completion 一度是特例（手動放在 `~/.omz-custom/plugins/chezmoi/_chezmoi`，
換機就沒了）。曾經寫過一支 `run_onchange` script 去 generate 它 —— 後來發現
**oh-my-zsh 本身就內建 `plugins/chezmoi`**，會自己 lazy-generate completion 並 cache
到 `$ZSH_CACHE_DIR`。所以那支 script 刪了，`chezmoi` 移進 `omzPlugins` 就好。
教訓：加自訂機制之前先確認上游有沒有現成的。

---

## 移除紀錄

### 2026-09 換機前盤點

依上面的原則盤了一次，`Brewfile` 從 55 個 formula 降到 33 個（+ `derailed/k9s` tap，
因為 k9s 不在 homebrew-core）。實際執行 `brew-prune.sh --yes` 之後 Cellar 剩 2.4 GB，
連同 `brew cleanup` 一共釋出約 1.3 GB。

**重複 / 衝突（留一個就好）**

| 移除 | 理由 |
|---|---|
| `zsh-autosuggestions`、`zsh-syntax-highlighting` | 跟 oh-my-zsh custom plugin 完全重複。兩份都在，實際載到哪一份要看 `.zshrc`，是最難查的那種問題 |
| `terraform` | 選定 `opentofu`。機器上的 terraform 其實只是 `terraformer` 的依賴 |
| `kustomize` | `kubectl -k` 已內建 |
| `pipx` | `uv` 取代 |
| `nvm` | node 由 brew 管。omz 的 nvm plugin 還會包一層 `node()` wrapper，反而遮蔽真正的 node |
| `node@22` | 跟 `node` 併存。留 `node` |
| `postgresql@14` | 跟 `@17` 併存。留 `@17` |
| `docker`（cask） | `docker-desktop` 的舊名，同一個東西 |
| `gcloud-cli`、`google-cloud-sdk`（cask） | **這兩個本來就不該在**。gcloud 走官方 archive，cask 版會因為 brew 升 Python 而壞掉，見 DECISIONS |

**從未使用（沒有 config 目錄、history 0 筆）**

`helm`、`argocd`、`step`、`grpcurl`、`jwt-cli`、`eksctl`、`cue`、`d2`、
`graphviz`、`httpie`、`age`

- `httpie` → `curl` + `jq` 夠用
- `d2` / `graphviz` → 圖改用 mermaid（GitHub 原生會 render，不用裝東西）
- `age` → 原本留給「真的非得加密進版控的例外」，但那個例外從來沒發生。真需要再裝

**最後使用超過 12 個月**

| 移除 | 最後痕跡 |
|---|---|
| `minikube` | `~/.minikube` 2024-08 |
| `terraformer` | 從未使用，而且 348 MB |
| `pandoc` | 從未使用，259 MB |

**新增**

| 新增 | 理由 |
|---|---|
| `rtk` | Claude Code 的 token proxy，天天在用，之前漏宣告 |
| `fd` | 檔名搜尋。跟 `ripgrep` 不是競品 —— 見下面「搜尋三件套」 |

### 搜尋三件套

常被誤會成「互相取代」，其實各管一件事，三個都要：

| 工具 | 管什麼 | 特點 |
|---|---|---|
| `ripgrep`（`rg`） | **內容**搜尋 | 這件事上沒有對手。預設尊重 `.gitignore` |
| `fd` | **檔名**搜尋 | 不是 rg 的競品，是互補（rg 找檔案裡面，fd 找檔案本身） |
| `fzf` | **互動式過濾** | 接在任何輸出後面用，不限於搜尋 |

**只有 `fzf` 需要 oh-my-zsh plugin。** `ripgrep` 和 `fd` 的 omz plugin 已經被 upstream
移除了（現在 master 有 362 個 plugin，沒有這兩個）—— 因為這兩個工具自己就附 zsh 補完，
brew 會 link 到 `/opt/homebrew/share/zsh/site-functions/{_rg,_fd}`。`~/.zshrc` 會在
oh-my-zsh 跑 `compinit` **之前**把那個目錄加進 `FPATH`，所以補完直接就有。

> 踩過的坑：一開始把 `ripgrep` / `fd` 加進 `.chezmoidata.yaml`，結果每次開 shell 都印
> `[oh-my-zsh] plugin 'ripgrep' not found`。加 plugin 之前先確認 upstream 現在還有沒有
> 那個 plugin —— 這個 repo 只列清單，清單寫錯不會有人幫你檢查。
`~/.zshrc` 裡另外包了 `ff`（找檔案）、`fdir`（找目錄）、`rgh`（連 .gitignore
和隱藏檔一起搜）、`fe`（rg 找內容 → fzf 挑 → 開 editor）。

**保留但差點被誤判**

| 保留 | 為什麼留 |
|---|---|
| `terraform` 的替代 `opentofu` | `~/.terraform.d/` 2026-09 還在動 |
| `azure-cli` | `~/.azure` 2026-09。雖然 513 MB |
| `rbenv` / `ruby-build` | `~/workspace` 底下有三個 Gemfile 專案 |
| `telnet` / `mtr` | history 有紀錄，查網路問題的主力 |
| `k9s` / `kubernetes-cli` / `kubectx` | history 高頻 |

**移出 Brewfile.gui 但留在機器上**（進 `Brewfile.unmanaged`）

`docker-desktop`、`docker`（Caskroom 裡指向 docker-desktop 的 rename symlink）、
`session-manager-plugin` —— 安裝時需要人在場，或只是偶爾要用。

`ghostty`、`telegram`、`claude-code` 本來也在這裡，2026-09 確認後從機器上移除
（`claude-code` 改用官方 curl installer）。

**shell 設定檔從五個變三個**

`~/.common_env`、`~/.bash_alias`、`~/.bashrc` 全部移除，內容合併進
`~/.zprofile`（PATH / 環境變數）和 `~/.zshrc`（alias / 函式 / 補完）。
`~/.env` 的角色由 zsh 慣例的 `~/.zshenv` 接手。理由見
[DECISIONS「zsh 的設定檔只留三個」](DECISIONS.md)。

舊檔由 `.chezmoiremove` 在 apply 時自動從 `$HOME` 清掉。
順手修掉的既有 bug：`~/.zshrc` 原本在 oh-my-zsh 跑完 `compinit` 之後才把 brew 的
`site-functions` 加進 `FPATH`，所以必須再 `compinit` 一次 —— 白花一次啟動成本。
改成在 `source $ZSH/oh-my-zsh.sh` 之前加，第二次 `compinit` 就可以拿掉了。
另外拿掉 Cloud Foundry CLI 的補完（`cf` 其實是同名的 npm 套件，不是 CF CLI）
和約 50 行 oh-my-zsh 樣板註解。

**其他清掉的東西**

- `dot_oh-my-zsh/`、`dot_omz-custom/`：un-vendor 之後留下的空目錄（只剩 `.DS_Store`）。
  留著會讓 chezmoi 以為要管理 `~/.oh-my-zsh`，跟 external 打架
- `oh-my-zsh-master.tar.gz`：1.9 MB 的下載殘骸
- `images/`（1.1 MB，4 張 PNG）：README 和 docs 都沒有引用。需要時從 git 歷史取回
- `bin/`：空目錄
- 舊 alias：`docker-hexo` / `hexo`（指向已不存在的 `~/workspace/rammusxu.github.io`）、
  `docker-debug-image`、`git-master`、`git-new-branch`、`git-pr-fork`

**Tap**

`homebrew/bundle` 也移除了 —— `brew bundle` 從 Homebrew 4.x 起是**內建指令**
（`$(brew --repo)/Library/Homebrew/cmd/bundle.rb`，`brew commands` 列得出來），
那個 tap 是舊時代的產物。實測 untap 之後 `brew bundle check` 照樣正常。

`cue-lang/tap`、`derailed/k9s`、`hashicorp/tap`、`manaflow-ai/cmux`、
`mike-engel/jwt-cli`、`weaveworks/tap` 都可以 untap —— 對應的 formula 要嘛移除了，
要嘛 homebrew-core 已經收錄。`make prune` 會列出來。

最後只留 `derailed/k9s` 一個 tap（k9s 不在 homebrew-core）。

### 盤點之後又調整的（人的判斷推翻證據）

自動化的證據只能說「這台機器上沒有痕跡」，不等於「不需要」。以下是看完清單
之後手動調回來的：

| 調整 | 理由 |
|---|---|
| `saml2aws` **加回** | `~/.saml2aws` 是 2024-03，但那是「換 AWS 短期憑證」的工具 —— 平常不會留下 config 變動。移掉會在真的要登入時卡住 |
| `podman` **加回** | 雖然日常用 docker，仍要留著 |
| `gemini-cli` **移除** | 原本因為 history 有 12 筆而保留，確認不再用 |
| `k3d` **移除** | 原本留著當 minikube 的替代，確認本機不需要跑 cluster。所以「本機 cluster」這件事現在兩個工具都沒有了 —— 需要時再裝 |
| `telegram` cask **移除** | 原本放在 Brewfile.unmanaged（機器上留著不管理），確認不用了 |
| `claude-code` cask **移除** | 改用官方 curl installer（`~/.local/bin/claude`）。brew cask 那份是 2.1.153，比 curl 版落後，而且兩份併存時 PATH 上跑到哪一份要看順序 |

教訓：`brew leaves` 和 config 目錄的 mtime 只是**線索**，不是判決。
「偶爾才用、但用的時候不能沒有」的工具（憑證類、災難處理類）不會留下痕跡。

### 執行時踩到的三件事（都反饋回 script 了）

**① `brew autoremove` 清不掉「當初手動裝過」的孤兒。**
brew 只會 autoremove 標記為「非 on-request」的套件。一個當初 `brew install` 過、
現在沒人要的套件（這次是 `gdk-pixbuf`）會永遠留著，而它底下整串依賴
（cairo / pango / harfbuzz / glib …）也因為「被它需要」而免疫。
→ `brew-prune.sh` 改成**迭代**：拔掉一層、`autoremove`、再看有沒有新的 leaf 浮上來，
最多 10 圈。

**② `brew leaves` 看不到被記成依賴的套件。**
`terraform`、`cue`、`jwt-cli`、`eksctl`（合計約 260 MB）當初是被別的套件拉進來的，
所以不在 `brew leaves` 裡，第一輪 prune 完全沒看到它們。迭代之後才浮出來。
（試過用「宣告清單 + 遞歸依賴 vs 已裝清單」來抓，35 項全是誤報 —— `brew deps` 是拿
現在的 formula 定義去解，跟機器上當初裝的版本對不上。已放棄，理由寫在
`scripts/lib-brewfile.sh` 裡。）

**③ 有些 cask 一定要 sudo，非互動式清不掉。**
`mactex`、`powershell` 是 pkg-based cask，uninstall 會呼叫 `sudo rm`。
沒有 TTY 就會失敗。這兩個要人在終端機前面自己跑：

```bash
brew uninstall --cask mactex powershell
```

**`mactex` 特別值得清** —— 上面那一整串 ghostscript / tesseract / cairo / pango
（約 500 MB）全都是它的依賴，只有它走了那些才會變成孤兒被 prune 掉。
移完之後再跑一次 `./scripts/brew-prune.sh --yes`。

### 順手修掉的東西

| 修了什麼 | 為什麼 |
|---|---|
| `psql` 進 PATH | `postgresql@17` 是 keg-only，brew 不 link。Brewfile 留它就是為了 psql client，但實際上 `psql` 叫不到 |
| `rbenv init` 傳對 shell | 原本寫死 `zsh`，但 `~/.common_env` 連 bash 也會 source |
| Antigravity 的 PATH | 從舊 clone 的未 commit 修改救回來，改成 `[ -d ]` guard |
| gcloud 改用官方 archive | 原本 `gcloud` 是從 brew cask 來的（`gcloud-cli` + `google-cloud-sdk` 兩個都裝了）。已裝好 `~/google-cloud-sdk`（自帶 Python 3.14，不依賴 brew python）並移除兩個 cask |
| `lib-brewfile.sh` 只准 bash source | 在 zsh 手動 source 時 `BASH_SOURCE` 是空的，`dirname ""` = `.`，`REPO` 會靜靜地指到上一層目錄 —— 又是一次「不會報錯的錯」 |

### 怎麼把東西加回來

```bash
brew install <formula>          # 先確認真的要用
# 然後把那一行加進 Brewfile，並在這裡補一行「為什麼又要了」
```
