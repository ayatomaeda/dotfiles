# スタートガイド

この共通のモジュールで**使えるようになっているもの**と、その呼び出し方の早見表。
使い方と、なぜそう決めたかは [`README.md`](../README.md) を参照。

## シェル (zsh)

キーマップは emacs (`Ctrl-A` / `Ctrl-E` などの標準操作)。

### キー

| キー / 入力 | 動き |
|---|---|
| `Ctrl-R` | 履歴を fzf で絞り込み、選んだコマンドをプロンプトに置く |
| `Ctrl-T` | カレント以下のファイル・ディレクトリを fzf で選び、カーソル位置にパスを挿入 (`Tab` で複数選択) |
| `Ctrl-G` | `~/git` 配下 (ghq 管理) のリポジトリを選んで `cd`。入力済みの文字列が初期クエリになる |
| `**<Tab>` | fzf で補完。`vim **<Tab>` でファイル、`cd **<Tab>` でディレクトリ、`kill **<Tab>` でプロセス |
| `Esc` → `c` | ディレクトリを選んで `cd` (fzf の `Alt-C`)。`Esc` を押して離してから `c`。`⌥C` は Ghostty の `macos-option-as-alt` が未設定のため `ç` になる |

fzf の画面内: `Ctrl-J` / `Ctrl-K` (または `↓` / `↑`) で移動、`Enter` で確定、`Esc` で中止。

### コマンド

| 入力 | 動き |
|---|---|
| `z <部分文字列>` | 一度訪れたディレクトリへ移動 (zoxide) |
| `zi <部分文字列>` | 同じ候補を fzf で選ぶ |
| `ll` / `la` | `ls -l` / `ls -al` (色・種別記号付き) |
| `history` | 日時付きで履歴を表示 |
| `bat <file>` | 構文強調 + ページャで読む。`cat` は置き換えていないので名前で呼ぶ |
| `rg` / `fd` | 内容検索 / ファイル名検索 |
| `nvim` | `EDITOR` / `VISUAL` の実体。プラグインは入れていない |

### 移動の使い分け

| 行きたい場所 | 使うもの |
|---|---|
| `~/git` 配下のリポジトリ | `Ctrl-G` (訪れたことがなくても候補に入り、あいまい検索できる) |
| 一度訪れた場所 | `z <ディレクトリ名の一部>` (例: `z down` → `~/Downloads`) |
| 綴りがうろ覚え | `zi` (`z` と同じ候補を fzf のあいまい検索で選ぶ) |
| カレント以下 | `Esc` → `c` |

`z` の一致規則 (zoxide 0.10 で実測):

- **最後の語はディレクトリ名 (パスの末尾の要素) に含まれる必要がある** — `z dot` や `z files` で
  `dotfiles` に行けるが、`z git` では `~/git/...` 配下のリポジトリには行けない。
- 大文字小文字は区別しない。前の語は親ディレクトリに順に一致させて絞り込む (`z aya dot`)。
- **あいまい検索ではない** — `z Dowlo` は `Downloads` に一致しない。綴りに自信がなければ `zi`。

候補が少ないと感じたら、なぜ記録されないかを [`README.md`](../README.md) の「移動」で確認する。

### プロンプト (starship)

2 行構成で、入力は常に 2 行目の `❯` から。

```
dotfiles on  main [!?⇡1] via ❄️ impure (nix-shell) direnv loaded/allowed took 3s
❯
```

| 表示 | 意味 |
|---|---|
| `❯` が赤 | 直前のコマンドが失敗した |
| `[...]` | git の状態。`!` 変更あり / `+` ステージ済み / `?` 未追跡 / `$` stash あり / `⇡` `⇣` リモートとの差 / `=` 衝突 |
| `❄️ ... (nix-shell)` | `nix develop` / `nix shell` の中にいる |
| `direnv loaded/allowed` | このディレクトリの `.envrc` が読み込まれている |
| `took 3s` | 直前のコマンドが 2 秒以上かかった |

gcloud のアカウントは表示しない。確認するときは `gcloud config list`。

## プロジェクトごとの環境 (direnv)

`.envrc` があるディレクトリに入ると環境が切り替わる。**初回だけ許可が要る**。

```sh
$ echo 'use flake' > .envrc   # そのリポジトリの flake.nix の devShell を使う
$ direnv allow                # 内容を確認してから許可。.envrc を書き換えるたびに再度必要
$ direnv deny                 # 許可を取り消す
```

`use flake` の結果は nix-direnv がキャッシュするので、2 回目以降の `cd` は速い。

## git

| コマンド | 動き |
|---|---|
| `git diff` / `log -p` / `show` / `blame` | delta で色付き表示 |
| `git dft` | difftastic で構文単位の差分。`git dft --stat` のように引数も渡せる |
| `git commit` | 1Password の SSH 鍵で自動署名。1Password の承認 (Touch ID 等) を求められることがある |
| `ghq get <owner>/<repo>` | `~/git/github.com/<owner>/<repo>` へ clone (以後 `Ctrl-G` の候補に入る) |

delta の画面は `less` なので、`q` で終了、`/` で検索、`n` / `N` で次 / 前の一致。

## ssh

- 鍵は 1Password の SSH agent が持つ。ディスク上に秘密鍵は無い
- 同じホストへの接続は、切断後 10 秒間使い回される (`ControlPersist`)。続けて `scp` / `ssh` しても再認証しない。github.com は対象外

## Ghostty

キー割り当ては既定のまま。主なもの:

| キー | 動き |
|---|---|
| `⌘T` / `⌘N` | 新しいタブ / ウィンドウ |
| `⌘D` / `⌘⇧D` | 右 / 下へ分割 |
| `⌘[` / `⌘]` | 前 / 次の分割へ |
| `⌘⌥` + 矢印 | その方向の分割へ |
| `⌘⌃` + 矢印 | 分割のサイズ変更 (`⌘⌃=` で均等) |
| `⌘⇧Enter` | 分割の最大化 / 戻す |
| `⌘↑` / `⌘↓` | 前 / 次のプロンプトへスクロール |
| `⌘K` | 画面クリア |
| `⌘⇧,` | 設定の再読み込み (switch で Ghostty の設定を変えた後) |

全一覧は `ghostty +list-keybinds`。

## tmux

prefix は既定の `Ctrl-b`。マウスを有効にしてあり、履歴は 50000 行、色は 256 色 + 24bit。

| キー | 動き |
|---|---|
| `Ctrl-b c` | 新しいウィンドウ |
| `Ctrl-b %` / `Ctrl-b "` | 左右 / 上下に分割 |
| `Ctrl-b` + 矢印 | ペイン移動 |
| `Ctrl-b d` | デタッチ (`tmux a` で戻る) |

### スクロールとコピー (copy-mode)

ホイールか `Ctrl-b [` で copy-mode に入る。copy-mode の間は右端にスクロールバーが出る。
キー操作は vi 式。

| キー | 動き |
|---|---|
| ホイール / `Ctrl-u` `Ctrl-d` | スクロール / 半ページ移動 |
| `[` / `]` | 前 / 次のプロンプトへ (長い出力の先頭に戻る) |
| `?` / `/` | 上 / 下へ検索 (`n` `N` で次へ) |
| `v` / `V` / `Ctrl-v` | 選択開始 / 行選択 / 矩形選択 |
| `y` | コピーして copy-mode を抜ける |
| マウスでドラッグ | コピー (スクロール位置はそのまま) |
| `q` | copy-mode を抜ける |

コピーは macOS のクリップボードに入る。Ghostty 自身の選択を使いたいときは `⌥` を押しながらドラッグ。

## herdr

エージェント作業用。tmux とは入れ子にせず、Ghostty の別のウィンドウ / タブで使う。
prefix は tmux と同じ `Ctrl-b` だが、割り当てが違う。

| キー | 動き |
|---|---|
| `Ctrl-b v` / `Ctrl-b -` | 左右 / 上下に分割 |
| `Ctrl-b h` `j` `k` `l` | ペイン移動 |
| `Ctrl-b z` / `Ctrl-b x` | ズーム / ペインを閉じる |
| `Ctrl-b c` / `Ctrl-b n` `p` | 新しいタブ / 次・前のタブ |
| `Ctrl-b w` | ワークスペースの一覧 |
| `Ctrl-b q` | デタッチ (`herdr` で戻る) |
| `Ctrl-b ?` | キーの一覧 |

マウスでのクリック・境界のドラッグ・右クリックメニューも使える。

設定画面 (`Ctrl-b s`) で変えても保存されない (下の「設定を変える」)。

## Claude Code のステータスライン

```
󰚩 Opus │ 󰧑 ▰▰▰▱▱▱▱▱▱▱  30% │ 󰘬 main │ +12 -3 │ 󰈮 2
󰥔 ▰▰▱▱▱▱▱▱▱▱  20%  resets at 14:00
󰃭 ▰▱▱▱▱▱▱▱▱▱  10%  resets at 9/20 9:00
```

| 行 | 内容 |
|---|---|
| 1 | モデル / コンテキスト使用率 / ブランチ / このセッションで増減した行数 / 変更中のファイル数 |
| 2 | 5 時間枠のレート制限と、リセット時刻 |
| 3 | 7 日枠のレート制限と、リセット時刻 |

バーは 50% で黄、80% で赤になる。2〜3 行目はセッション最初の応答が返るまで出ない。

## 設定を変える

設定ファイルはすべて宣言から生成していて、`~` にあるのは読み取り専用のコピー。
**リポジトリの宣言を直して switch する**のが唯一の変え方。どの環境でも同じにしたいものはこのリポジトリに、
その環境だけのものは利用側のリポジトリに書く。このリポジトリの変更は、利用側で lock を更新してから switch
すると反映される ([`README.md`](../README.md) の「変更を試す、反映する」)。

```sh
$ sudo darwin-rebuild switch --flake <利用側のリポジトリ>#<host>
```

| 変えたいもの | 書く場所 |
|---|---|
| Ghostty (テーマ・フォント・透過など) | `modules/common/ghostty.nix` |
| Claude Code (`settings.json`、プラグイン、権限) | `modules/common/claude-code.nix` |
| Claude Code のステータスライン | `claude/statusline-command.sh` |
| ssh の共通設定 | `modules/common/ssh.nix` |
| ssh の接続先 | 利用側の `programs.ssh.settings.<host>` |
| herdr | `modules/common/terminal.nix` の `programs.herdr.settings` |
| どの環境でも使うパッケージ | `modules/common/packages.nix`、`modules/darwin/homebrew.nix` |
| その環境でだけ使うパッケージ、git の identity | 利用側 |

**アプリの設定画面での変更は保存されない。エラーも出ない。**

- Claude Code の `/config`・`/theme`・権限の「常に許可」・プラグインの切り替え:
  そのセッションだけ効いて、次に起動すると戻る。
- herdr の設定画面 (`Ctrl-b s`): apply しても何も変わらない。

気に入った設定は、上の表の場所に書いて switch する。
