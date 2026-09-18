# CLAUDE.md

macOS (Apple Silicon) の環境を Nix flake + nix-darwin + home-manager で宣言的に管理するための
**共通のモジュール**。このリポジトリはホストを宣言しない。利用側のリポジトリ (家の構成、会社の構成など) が
flake の input として取り込み、ホストの構成と環境固有の値を与える。使い方は `README.md`、
日々の操作は `docs/GUIDE.md`、要件は `openspec/specs/` を参照。

コメントの括弧内にある change の名前 (`remote-agent-forwarding` など) は、所有者の非公開の
設計記録を指す。経緯はこのリポジトリには無く、現在の要件だけが `openspec/specs/` にある。

## public のリポジトリとしての決まり

**このリポジトリは公開されている。** 環境固有の値と私的な情報を書かない。

- **値は利用側が与える。** ユーザー名、git の identity、署名鍵、ssh の接続先、`stateVersion`、
  特定の環境でだけ使うパッケージは、利用側が home-manager / nix-darwin の標準の option に直接書く。
- **固有名を書かない。** ホスト名、ドメイン、アドレス、利用側のネットワークやクラスタの構成を、
  コード、コメント、コミットメッセージ、ブランチ名、PR と issue の文章のどこにも書かない。
  実測の記録は、役割の名前 (接続元の Mac、接続先の Mac、所有者の端末) で書く。
- 所有者の家の端末には、public への push とエージェントの `gh` の書き込みを止める検査がある。
  **それ以外の端末と GitHub の画面からの公開は、後から見つかるだけで止まらない。**
- **switch は、利用側の `flake.lock` が固定した版からだけ行う。** 手元のクローンを
  `--override-input` で指すのは、build と評価の確認だけにする (下の「振る舞い不変の検証」)。

## 構造の原則

```
flake.nix          darwinModules.default / homeModules.default (input は持たない)
modules/darwin/    macOS 共通 (Nix 設定・sshd・home-manager の統合) + homebrew.nix (共通のリスト)
modules/common/    OS 非依存のユーザー設定
                   (options / packages / zsh / git / tmux / terminal / ghostty /
                    claude-code / ssh / neovim)
ssh/rc             sshd がログインのたびに実行するスクリプト
claude/            Claude Code のステータスラインのスクリプト
```

- **依存は一方向** — このリポジトリから利用側を参照しない。
- **core が読む値だけを `dotfiles.*` の options で渡す** (`modules/common/options.nix`)。
  **option を作る根拠は「ホストが値を与える」か「既定値をホスト依存の情報から導出する」
  のどちらかに限る。定数を option に置き換えない** — 指し先が増えるだけで何も表現しない。
  core が読まない値 (git の identity、ssh の接続先など) は option にせず、利用側が標準の option に
  直接書く (モジュールシステムがマージする)。
  現在の option は `onePassword.enable` (既定値を `hostPlatform` から導出) と
  `git.signingKey` (利用側が与える) の 2 つ。
  モジュール間の受け渡しに使うものは `internal = true` を付けて設定項目と区別する。
- **リストに置いたものは、すべての利用側に入る。** `home.packages` と Homebrew のリストは
  利用側で引けない。どの環境でも使うものだけを置く。
- **利用側が与えるものに依存するときは、約束としてコメントに書く** (Ghostty の本体とフォント、
  1Password のアプリ、agent の転送先、home-manager の darwin モジュールの読み込み)。
- **プラットフォーム固有の記述はモジュール内部で評価時に分岐させる**
  (`lib.mkIf pkgs.stdenv.hostPlatform.isDarwin`)。ホスト側で分岐させない。シェルの
  実行時分岐 (`$OSTYPE` の判定) で代替しない。
- `pkgs.stdenv.isDarwin` は deprecated。`pkgs.stdenv.hostPlatform.isDarwin` を使う。

## 振る舞い不変の検証 (drvPath 照合)

**ファイル分割・モジュール化・値の options 化のように「振る舞いを変えない意図」の変更は、
変更前後で `drvPath` が一致することを確認してから次へ進む。** このリポジトリはホストを持たないので、
**利用側のリポジトリで**、手元のクローンを指して比べる。

```sh
# 利用側のリポジトリで、変更前に記録
nix eval --raw '.#darwinConfigurations.<host>.config.system.build.toplevel.drvPath'
# 変更後 (このリポジトリの変更は未 commit でも git add してあれば見える)
nix eval --raw --override-input core path:../dotfiles \
  '.#darwinConfigurations.<host>.config.system.build.toplevel.drvPath'
```

一致しなければ `nix derivation show` / `nix-diff` で原因を特定する。一致させられない
差分は理由を記録する。**`--override-input` を付けたまま switch しない** — 動いている世代が
どのコミットにも無い構成になる。

- **`home.packages` と Homebrew のリストは、読み込み順につながる。** 要素の順序が変わると
  `drvPath` も変わる。条件付きにするときは `lib.optionals` を挟んで**既存の並びを保つ**。
  nix-darwin の Brewfile は並べ替えられない。
- `drvPath` が変わる意図的な変更では、**実体化した出力の比較**に落とす
  (`home-manager-path` のエントリ一覧と symlink の解決先、Brewfile の行の集合を突き合わせる)。
- 撤去した変更が完全に戻ったことも、この照合で確認できる。

## コミットメッセージ

**`##[` で始まる行を本文に入れない。** GitHub Actions はログ中の `##[error]` や
`##[warning]` を workflow command として解釈する。`update-flake-lock` の内部ステップは
直前のコミット本文をログに echo するため、調査結果としてエラーログを逐語で引用すると
**存在しないエラー注釈が workflow のログに出る**。実際に一度、run は success なのに
エラーが 6 件表示されて誤診の原因になった。

ログを引用するときは記号を落とすか言い換える。

```
悪い:  ##[error]GitHub Actions is not permitted to create or approve pull requests.
良い:  error: GitHub Actions is not permitted to create or approve pull requests
良い:  PR 作成が "not permitted to create or approve pull requests" で拒否された
```

## 適用のしかた

`switch` は所有者が実行する。アシスタントは編集と非破壊の確認 (`darwin-rebuild build`、
dry-run、評価) までを担当する。このリポジトリの変更は、マージした後に利用側で lock を更新し
(`nix flake update core`)、その利用側のコミットから switch して反映する。

## 踏むと痛い箇所

- **`homebrew.onActivation.cleanup = "uninstall"` の利用側では、宣言から外した Homebrew パッケージは
  次の `switch` で即座に削除される** — このリポジトリのリストから外すのも同じ。宣言を減らす変更の前に
  `brew bundle cleanup` の dry-run で削除対象を提示し、承認を得る。
  - `brew bundle check` は、**導入済みでも新しい版があるだけのもの**を「needs to be installed or
    updated」と報告する (`onActivation.upgrade = false` の構成では常に何件か出る)。直す前に
    `brew list --cask --versions <name>` / `mas list` で導入済みかを確かめる。確認のたびに Homebrew を
    更新させないよう `HOMEBREW_NO_AUTO_UPDATE=1` を付ける。
- **`nix search nixpkgs` は `flake.lock` を見ていない** — Determinate Nix の
  `extra-nix-path` が FlakeHub の nixpkgs-weekly を指しているため。パッケージの有無は
  pin 済みの rev に対して評価して確認する。

  ```sh
  nix eval --raw github:NixOS/nixpkgs/<lock の rev>#legacyPackages.aarch64-darwin.<pkg>.version
  ```
- **非公式 tap は `trusted = true` が必要** — Homebrew 6.0.0 以降、信頼していない tap の
  cask は黙ってスキップされる。既存機では導入済みのため症状が出ず、新しいマシンで
  初めて壊れる。
- **設定ファイルは宣言から生成する。out-of-store symlink を使わない** — 所有者の方針
  (`retire-out-of-store-symlinks`)。「編集して即反映」は手元の実体とリポジトリの宣言をずらすので
  不要とされた。新しい設定ファイルは `programs.*` の native モジュール (無ければ `home.file` の
  store コピー) で置く。`mkOutOfStoreSymlink` を増やさない。
- **アプリの設定画面での変更は保存されない — しかもエラーが出ない** — `~` の設定ファイルは
  store への読み取り専用のコピーなので、Claude Code の `/config`・`/theme`・権限の「常に許可」は
  そのセッション限りで次の起動で消え、herdr の設定画面 (`prefix+s`) は apply しても何も起きない
  (`/theme` と herdr は実測。残りは公式ドキュメントの記述)。恒久的な変更は宣言を直して switch する。
  所有者が「設定が消えた」と言ったらまずこれを疑う。
  - **`programs.claude-code.marketplaces` を使わない。** `~/.claude/plugins/known_marketplaces.json`
    まで読み取り専用になるが、それは Claude Code 自身が書き換えるファイル。marketplace は
    `settings.extraKnownMarketplaces` に書く。
- **native モジュールは頼んでいないものまで書く** — `programs.ghostty.enableZshIntegration` の既定
  (true) は `.zshrc` に Ghostty のシェル統合をもう 1 つ足し、`terminal.nix` の手書き (mkOrder 1500)
  と二重になった。`programs.ssh.enableDefaultConfig` の既定 (true) は `Host *` に
  `UserKnownHostsFile` などを注入する。どちらも `false` にしてある。**新しい `programs.*` を
  足したら、生成物の木 (`home-files`) を前の世代と突き合わせて、意図した差だけかを見る。**
- **`programs.ssh.settings` のブロックの順序** — `settings."*"` は必ず最後に出力され、ほかは
  属性名の昇順に並ぶ (利用側が足したブロックも同じ)。ssh は同じキーワードの最初の値を採るので、
  ホスト個別の値が `Host *` と重なるときは `"*"` に置いた側が負ける (意図どおり)。`Host *` 以外で
  重なるキーワードを持つブロックを足すときは、昇順で意図した順になるか生成物で確かめる。
  中身の無い `Host` 行 (`<host> = { };`) は zsh の補完の候補になるので、利用側で消さない
  (`ssh -G` には現れないので、消えても気づけない)。
- **`IdentityAgent` は ssh agent 転送を上書きする — だから 1Password の `Match` (`ssh.nix`) は
  ssh 越し (`SSH_CONNECTION` があり、転送ソケットが実在する) のときは適用しない** — 無条件に置くと、
  ssh 越しのシェルでもそのホストのローカル 1Password が使われ、承認が**接続先の無人の画面**に出て止まる
  (`remote-agent-forwarding`)。ssh 越しでは既定どおり転送された `SSH_AUTH_SOCK` を使い、
  署名は `git.nix` のラッパーが `op-ssh-sign` ではなく `ssh-keygen` を選ぶ。
  - 判定に `SSH_TTY` を使わない (1Password 公式の例はこれ)。TTY なしの実行
    (`ssh <host> 'git …'`) で空になり、`op-ssh-sign` も `failed to fill whole buffer` で失敗する。
  - **ソケットの実在も見る。** tmux は detach で環境を戻さないので、ssh で attach して
    切断した後、接続先の Mac の前のペインに古い `SSH_CONNECTION` が残る。`SSH_CONNECTION` だけで
    判定すると、ローカルの git の操作と署名が消えたソケットを見て失敗する。条件は
    `ssh.nix` の 1Password の `Match` と `git.nix` の署名ラッパーの 2 か所にあり、そろえておく。
  - `Match exec` の変数は引用符で囲む。`$SHELL` が sh / bash だと値が分割され、
    ssh のたびに `test: too many arguments` が出る。
  - **herdr のペインは固定パスで判定する** (`herdr-remote-machines`)。herdr のサーバーは起動時の
    `SSH_AUTH_SOCK` を持ち続けて再接続で更新しないので、ペインでは `~/.ssh/agent-forward.sock` を
    使い、`ssh/rc` がログインのたびに先を張り替える。条件は `ssh.nix`・`git.nix` の
    署名ラッパー・`ssh/rc`・`terminal.nix` の 4 か所にまたがる。パスを変えるときは全部そろえる。
  - **`ssh/rc` は何も出力してはならない。** 標準出力は接続の出力に混ざり、herdr の中継、
    `ssh host 'git …'`、`scp` を壊す。**先が生きているリンクを張り替えてはならない** —
    `ControlPersist 10s` の短い接続がリンクを奪い、10 秒後に先が消える。
  - sshd の `ClientAliveInterval 15` / `ClientAliveCountMax 4` を外さない。スリープした Mac の
    転送ソケットが残り続け、`ssh/rc` が張り替えず、herdr のペインの署名が応答しない agent で止まる。
  - **転送は利用側が、所有者の端末への接続にだけ宣言する** (`programs.ssh.settings.<host>.ForwardAgent`)。
    このリポジトリは転送を有効にしない。`ssh/rc` はこれを前提にしている。`-A` に頼らない —
    多重化接続では先に立った master が転送の有無を決め、後から `-A` を付けても効かない (実測)。
  - **判定は環境変数なので、古い環境を持つプロセスは誤る。** tmux の既存ペインは
    `tmux.nix` の `preexec` フックが読み直すが、フック配列はシェルスナップショットに載らない
    ので **Claude Code のシェルには効かない**。接続先の Mac の前で起動した Claude Code を
    接続元からの attach で使うと、承認は接続先に出る。attach 後に起動し直す。
  - 環境変数に頼らない判定 (ssh-agent-switcher、自作の走査スクリプト) を一度設計して
    捨てた。応答しない接続での停止や中継の循環など、自作部分に穴が続いたため。
    定番の構成を一部の状況だけで退けないこと (`remote-agent-forwarding` design の経緯)。

- **`programs.zsh.shellAliases` は Claude Code の実行環境へ波及する** — Claude Code の
  Bash ツールは `~/.claude/shell-snapshots/snapshot-zsh-*.sh` を読み込んで起動し、その
  スナップショットには **`zsh.nix` で宣言した alias がそのまま入る** (実測:
  `alias -- ls='ls -GF'` が載っている)。したがって `eza` / `bat` のような置き換え系ツールを
  `ls` / `cat` の alias で乗っ取ると、**人間の打鍵だけでなくエージェントの実行結果まで変わる**。
  置き換え系ツールは自分の名前で `PATH` に置き、既存コマンド名を奪わないこと。

- **スナップショットは使い回される — 撤去したはずの設定がエージェント側で生き残る** —
  `~/.claude/shell-snapshots/` のスナップショットはセッションごとに作り直されない
  (実測: 異なる日のファイルの md5 が一致)。そのため**エージェントの
  シェルは、リポジトリの現在の生成物ではなく過去の `.zshrc` を反映していることがある**。
  実例: Nix 移行で撤去した `ssh()` 関数 (リモートへ `.zshrc` を scp する) がスナップショット
  に残っており、エージェントが `ssh` を実行するたびに `Uploading .zshrc to ...` が走っていた。
  `dotfiles-management` の「リモートホストの環境を転送で同期してはならない」に反する挙動が、
  **リポジトリ側ではなくエージェントのキャッシュ経由で復活していた**。
  `.zshrc` から何かを消したとき、エージェントの実行環境からも消えたと考えないこと。
  確認は `type <name>` で定義元を見る。回避は `command <name>` で関数を迂回する。

- **スナップショットは配列を保存しない = zsh のフックはエージェントに届かない** —
  同じスナップショットが保存するのは alias / setopt / 関数 / `PATH` だけで、`typeset` 行が
  1 つも無い。`precmd_functions` / `chpwd_functions` は配列なので復元されず、**`direnv` も
  `zoxide` も Claude の Bash では発火しない** (実測: エージェントの実行環境で `.envrc` の
  あるディレクトリへ `cd` しても環境が読み込まれない)。エージェントに環境を渡すときは
  `direnv exec . <cmd>` と明示する。逆に言えば、フックを前提にした仕掛けを「エージェントでも
  効くはず」と考えないこと。

- **`core.pager` / `pager.<コマンド>` と `diff.external` は TTY の扱いが違う** — 前者は
  出力が TTY でないとき git が自動的にページャを無効化するが、**後者は TTY と無関係に起動する**。
  そのため `delta` を pager に置いてもエージェントの `git diff` は素の unified diff のままだが、
  `difftastic` を `diff.external` に置くと**エージェントが読む差分の形式まで変わる**。
  実測: パイプした `git diff` / `git log -p` / `git show` / `git blame` の ANSI エスケープは
  0 件、同じ `git diff` に PTY を与えると 1505 件。差分ツールを足すときは、どちらの経路に
  載るのかを先に確認する。

- **実行したプロンプトの置き換えは starship の `PROMPT` の代入方式に依存している** —
  `modules/common/terminal.nix` の `initContent` (`mkOrder 1400`) は、`starship init zsh` が
  `PROMPT` / `RPROMPT` を**1 回だけ**代入することを前提に、その値を控えて包んでいる。
  starship を更新したら、`darwin-rebuild build` だけでは壊れたことが分からない。**実際の対話
  zsh で**、実行後の行が `%n@%m %1~ %# コマンド` に置き換わることと、入力途中の Ctrl-C でも
  縮むことを確認する。
  あわせて次の 3 つは実測で踏んだもので、外すと黙って壊れる:
  (1) `zle-line-finish` の中で `PROMPT` を戻すと置き換わらない (描き直しは widget を抜けた後)。
  戻すのは precmd。
  (2) direnv のフックは precmd / chpwd のたびに `trap - SIGINT` を実行し、関数の `TRAPINT` を
  消す。precmd で定義し直している。
  (3) `TRAPINT` は関数なのでシェルスナップショットに載り、エージェントのシェルでも定義される。
  非対話では自分を外して SIGINT を送り直すことで、中断の伝わり方を関数なしと一致させている。

- **CI は Homebrew を守らない** — CI は Nix 構成の評価のみ。activation 時にしか起きない
  失敗 (とくに `brew bundle`) は検出できない。
- **`darwin-rebuild` は呼び出し側の PATH に依存しない** — スクリプトが冒頭で自分の
  `PATH` を上書きし、`coreutils` / `jq` / `git` / `nix` を store と
  `/nix/var/nix/profiles/default/bin` から解決する。`sudo` の PATH の扱いは無関係で、
  **世代がひとつでもあれば `sudo /run/current-system/sw/bin/darwin-rebuild` が必ず動く**。
  `darwin-rebuild` が本当に無いのは**世代が 0 個の初回だけ**で、そのときだけ
  `nix build .#darwinConfigurations.<host>.system` → `sudo ./result/sw/bin/darwin-rebuild`
  を使い、終わったら `result` を消す (GC ルートを残さない)。
  `sudo nix run nix-darwin -- switch` は registry 解決で master を取るため `flake.lock` の
  pin から外れるので、初回でも使わない。
  **かつて「sudo が PATH をリセットするため」と説明していたが、それは誤りだった**。
  ある Mac で command not found になった原因は、当時そのマシンに nix-darwin の世代が
  1 つも無く `darwin-rebuild` がどこにも存在しなかったこと。機構を測らずに症状から原因を
  推測した典型例。
- **sshd は公開鍵認証のみ — 鍵を壊すとリモートから締め出される** — authorized keys は利用側が
  宣言する (`users.users.<user>.openssh.authorizedKeys`)。パスワードに落ちないので、鍵を入れ替える
  変更は**本体の前で**適用し、既存のセッションを閉じずに別の接続で確かめる。
  認証方式の宣言 (`modules/darwin/default.nix`) は `/etc/ssh/sshd_config.d/100-nix-darwin.conf` に入り、
  macOS 自身の `100-macos.conf` より**ファイル名順で後ろ**にある。sshd は最初の値を採るので、macOS の
  更新で `100-macos.conf` が同じキーワードを持つと黙って負ける。確認は `sudo sshd -T`。
  root なしで確かめたいときは、build 結果の `etc/ssh/sshd_config.d/*` と
  `/etc/ssh/sshd_config.d/100-macos.conf` を一時ディレクトリへ集め、使い捨てのホスト鍵で
  `/usr/sbin/sshd -T -f <conf> -h <key> -C user=<user>,host=x,addr=1.2.3.4` を実行する。
- **`services.openssh.enable` を宣言しない** — `true` / `false` のどちらでも、switch の
  たびにリモートログインのオン / オフを巻き戻す。所有者は GUI で切り替えている。
- **アプリの「連携をインストール」コマンドを実行しない** — `herdr integration install claude` は
  `~/.claude/settings.json` に hook を足し、`~/.claude/hooks/herdr-agent-state.sh` を作る。
  前者は読み取り専用なので保存されず、**後者だけが宣言の外に残る** (`terminal-tooling`)。
  必要になったら hook スクリプトもリポジトリで管理する変更として行う。
- **`.hm-bak` は差分を取ってから消す** — `backupFileExtension` が退避したファイルには、
  そのホストでしか有効化していなかった設定が入っていることがある (実例:
  `~/.claude/settings.json`)。「バックアップだから消してよい」ではなく「リポジトリ版が
  新しいことを確認してから消す」。
- **`//` は浅いマージ** — `settings.user.signingkey` を `//` で足すと `user` 全体が
  置き換わり `user.name` / `user.email` が消える。`lib.recursiveUpdate` を使う。
- **状態の判定を PATH 依存の経路で行わない** — `command -v brew` を非対話 ssh で実行して
  「Homebrew 未導入」と誤診したことがある。絶対パスで確認する。`ssh-add -L` も
  `SSH_AUTH_SOCK` 次第で空になる。パス名の一致を数えるときは `grep -x` で完全一致に
  する (`grep 'local/bin'` は `/usr/local/bin` にもマッチする)。
  **`brew` を絶対パスで呼んでも、`brew` が内部で呼ぶコマンドは `PATH` から探される。**
  非対話 ssh の `PATH` には `/opt/homebrew/bin` が無いので、`ssh <host> '/opt/homebrew/bin/brew
  bundle check'` は `mas` を見つけられず、導入済みの Mac App Store アプリをすべて
  「needs to be installed」と報告した (実物は `mas list` にも `/Applications` にもあった)。
  ssh 越しに Homebrew の状態を確かめるときは `PATH=/opt/homebrew/bin:$PATH` を付ける。
  「未導入」「不足」という結果が出たら、直す前に実物 (`mas list`、`/Applications`) で裏を取る
  — アプリのファイル名は表示名と違うことがある (Kindle は `Amazon Kindle.app`)。

## 作業の進め方

規模のある変更は OpenSpec で proposal / design / specs / tasks を先に書き、フェーズ毎に
コミットして PR でレビューする。破壊的な操作は必ず対象一覧を提示して承認を得る。
