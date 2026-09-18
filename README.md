# dotfiles

macOS (Apple Silicon) の環境を **Nix flake + nix-darwin + home-manager** で宣言的に管理するための
共通のモジュール。

**このリポジトリはホストを宣言しない。** 利用側のリポジトリ (所有者の家の構成、会社の構成など) が
flake の input として取り込み、ホストの構成と環境固有の値 (ユーザー名、git の identity、ssh の接続先、
その環境でだけ使うパッケージ) を与える。所有者の環境のためのもので、第三者向けの互換性は約束しない。

**秘密はここに置かない。** SSH 秘密鍵、API トークン、kubeconfig の client-secret は、利用側にも置かない。

## 提供するもの

| 出力 | 中身 |
|---|---|
| `homeModules.default` | home-manager のモジュール (`modules/common/`)。zsh / git / tmux / 端末のツール / Ghostty / Claude Code / ssh / neovim の設定と、どの環境でも使う CLI ツール |
| `darwinModules.default` | nix-darwin のモジュール (`modules/darwin/`)。Nix の管理の無効化 (Determinate Nix 前提)、sshd の認証方式、home-manager の統合の設定、どの環境でも使う cask と App Store アプリのリスト |
| `darwinConfigurations.example` | **評価用の例の構成 (実在のホストではない)**。CI が評価して、モジュールが利用側なしでも壊れていないことを確かめる。利用側の書き方の見本も兼ねる |

| ファイル / ディレクトリ | 役割 |
|---|---|
| `modules/common/` | `options` / `packages` / `zsh` / `git` / `tmux` / `terminal` / `ghostty` / `claude-code` / `ssh` / `neovim` |
| `modules/darwin/` | macOS 共通の設定と `homebrew.nix` (リストだけ) |
| `ssh/rc` `claude/statusline-command.sh` | 宣言が読むスクリプトの本体。store へコピーされるので、編集は switch で反映 |
| `docs/GUIDE.md` | 使えるようになっているキー・コマンドの早見表と、設定を変えるときに書く場所 |
| `openspec/specs/` | 要件 |
| `.github/workflows/` | CI (例の構成の評価) と `flake.lock` の週次自動更新 |

## 使い方

利用側の `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = { url = "github:nix-darwin/nix-darwin/master"; inputs.nixpkgs.follows = "nixpkgs"; };
    home-manager = { url = "github:nix-community/home-manager/master"; inputs.nixpkgs.follows = "nixpkgs"; };
    core = {
      url = "github:ayatomaeda/dotfiles";
      # core の input は評価用の例の構成のためのもの。利用側の input にそろえる。
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-darwin.follows = "nix-darwin";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { nix-darwin, home-manager, core, ... }: {
    darwinConfigurations.<host> = nix-darwin.lib.darwinSystem {
      specialArgs = { inherit core; };
      modules = [
        ./hosts/<host>
        home-manager.darwinModules.home-manager   # core.darwinModules.default の前提
        core.darwinModules.default
        ./modules/darwin                          # 利用側の値 (下)
      ];
    };
  };
}
```

利用側のモジュールで、環境固有の値を**標準の option に直接**書く。core の宣言とはモジュールシステムが
マージする。

```nix
{ core, ... }:
{
  system.primaryUser = "<user>";
  users.users.<user> = {
    home = "/Users/<user>";
    openssh.authorizedKeys.keyFiles = [ ./keys/id_ed25519.pub ];
  };
  system.stateVersion = 6;
  homebrew = { enable = true; onActivation = { /* 方針は利用側が決める */ }; casks = [ /* その環境でだけ使うもの */ ]; };

  home-manager.users.<user> = {
    imports = [ core.homeModules.default ];
    home.stateVersion = "25.05";
    programs.git.settings.user = { name = "<name>"; email = "<email>"; };
    dotfiles.git.signingKey = builtins.readFile ./keys/id_ed25519.pub;   # 署名しないなら与えない
    programs.ssh.settings.<host> = { HostName = "…"; };
    home.packages = [ /* その環境でだけ使う CLI ツール */ ];
  };
}
```

### option

core が**読む**値だけを option にしている (`modules/common/options.nix`)。core が読まない値
(git の identity、ssh の接続先など) は、上のように標準の option に直接書く。

| option | 既定 | 意味 |
|---|---|---|
| `dotfiles.onePassword.enable` | macOS では `true` | 1Password の SSH agent を ssh の認証と git の署名に使う |
| `dotfiles.git.signingKey` | `null` | 署名に使う公開鍵。`null` なら署名の設定を出力しない |

### 利用側が与えるもの

core のモジュールが正しく動くために、利用側の宣言に頼っているもの。

| core の前提 | 利用側が与えるもの |
|---|---|
| `darwinModules.default` が `home-manager.*` を設定する | home-manager の darwin モジュールの読み込み |
| Ghostty の設定 (`package = null`、`font-family`) | Ghostty 本体と 2 つのフォント。core の Homebrew のリストにあるが、効くのは `homebrew.enable = true` のときだけ |
| 1Password の SSH agent と `op-ssh-sign` | 1Password のアプリ (同上) と、その SSH agent の有効化 |
| `ssh/rc` は、生きているリンクの先が所有者の端末の agent であることを前提に張り替える | **agent を転送する先は、所有者の端末に限る** (`programs.ssh.settings.<host>.ForwardAgent`)。core は転送を有効にしない |

### リストに置いたものは、すべての利用側に入る

`home.packages` と Homebrew のリスト (`brews` / `casks` / `masApps`) は、利用側で**引けない**。core には、
どの環境でも使うものだけを置く。その環境でだけ使うものは利用側が足す。

- **CLI ツール**は Nix ネイティブ (`home.packages` / `programs.*`)。
- **GUI アプリ (cask) と Mac App Store アプリ (mas)** は Nix では扱えないため、nix-darwin の `homebrew`
  モジュール経由で宣言的に Homebrew を駆動する。core は**リストだけ**を宣言し、`homebrew.enable` と
  `onActivation` (更新と cleanup の方針) は利用側が決める。
- **Claude Code** は、自動更新される native インストーラ (`curl -fsSL https://claude.ai/install.sh | bash`) で
  入れる。Homebrew 管理下だと自動更新が止まるため、リストに置いていない。

## 変更を試す、反映する

core を変えたら、**push する前に利用側で**確かめる。利用側のリポジトリで、手元のクローンを指す:

```sh
$ nix eval --raw --override-input core path:../dotfiles \
    '.#darwinConfigurations.<host>.config.system.build.toplevel.drvPath'
$ darwin-rebuild build --flake . --override-input core path:../dotfiles
```

**`--override-input` を付けたまま switch しない。** 動いている世代がどのコミットにも無い構成になる。
core の変更をマージしたら、利用側で lock を更新するコミットを作り (`nix flake update core`)、
そのコミットから switch する。

## 設計の方針

**設定ファイルはすべて宣言から生成する** (`retire-out-of-store-symlinks`)。Ghostty・herdr・
Claude Code・ssh の設定は `programs.*` に書き、`~` に置かれる実体は Nix store への読み取り専用の
コピーになる。**手元の実体とリポジトリの宣言がずれる経路を作らない** ためで、編集して即反映させる
out-of-store symlink は使わない。設定を変えるときはリポジトリを直して switch する。
アプリの設定画面での変更が保存されないことに注意 (下の「保存されない操作」)。

**依存の向きは一方向** — このリポジトリは利用側を参照しない。
**すべてのホストで同じ値になるものは option にしない** — 指し先が増えるだけで何も表現しないため。

プラットフォーム固有の記述は**モジュール内部で評価時に分岐**させる (`lib.mkIf pkgs.stdenv.hostPlatform.isDarwin`)。
ホスト側で分岐させたり、シェルの実行時分岐 (`$OSTYPE` の判定) で代替したりしない。

コメントの括弧内にある change の名前 (`refine-prompt-transient` など) は、所有者の非公開の
設計記録を指す。

## 端末のツール

`modules/common/terminal.nix` にまとめてある。**この端末は人間と Claude Code が同じシェル
構成を共有しており、主な使い手は非対話のエージェントである。** そのため一般的な「モダン
端末」構成のうち打鍵量を減らすもの (`zsh-autosuggestions` / `zsh-abbr` / `atuin`) は採らず、
次の 4 つに配分している。

| 役割 | ツール | 何のために |
|---|---|---|
| エージェントが走る | `jq` `ripgrep` `fd` | 呼ばれるコマンドが `PATH` にあること |
| 人間が出力を読む | `delta` `difftastic` `bat` | エージェントが生成した差分とファイルの可読性 |
| 人間がたまに打つ | `fzf` `zoxide` `starship` `direnv` | 移動と状態把握 |
| エージェントを並べる | `herdr` | 入力待ちで止まったエージェントを見つける |

入力の予測と補完の一覧は、実際に入れて試したうえで外した。`zsh-autosuggestions` と
`zsh-autocomplete` のどちらも、所有者の評価は「予測も候補も使い物にならない」だった。
候補の一覧から選びたいときは、打ちかけの文字を検索語にして開く `Ctrl-R` (履歴) と
`**<Tab>` (ファイル) を使う。

`programs.*` の native モジュールがあるものはすべてそれで宣言する。`initContent` に
`eval "$(<tool> init zsh)"` を手書きしない。例外は 2 つで、どちらも理由をコメントに残したうえで
`initContent` に置いている。

- ghq + fzf のウィジェット — `programs.*` で表現できない
- 実行したプロンプトの置き換え — starship の transient prompt が zsh では提供されない
  (home-manager の `enableTransience` は fish 専用)

### 差分の読み方 — `delta` と `difftastic` の使い分け

```sh
$ git diff                 # delta (常時)。TTY のときだけ効く
$ git dft                  # difftastic。構文木ベース
```

**`difftastic` を `diff.external` に置いていない。** `core.pager` / `pager.<コマンド>` は
出力が TTY でないとき git が自動的に無効化するが、`diff.external` は TTY と無関係に起動する。
恒久設定にすると**エージェントが読む `git diff` の形式まで変わる**。加えて `git log -p -15` で
delta の 3.7 倍遅い (0.73s / 2.70s)。

`git dft` が効くのは、Nix の設定で頻出する「既存ブロックを `lib.mkIf` / `lib.optionals` で
包む」変更である。再インデントを差分として数えないため、`git.nix` を `mkIf` で包んだ差分は
delta の 51 行に対し difftastic では 9 行になる。

### 移動

キーとコマンドの一覧、場面ごとの使い分け、`z` の一致規則は [`docs/GUIDE.md`](docs/GUIDE.md)。

`z` は履歴ベースなので**まだ訪れていないリポジトリには効かない**。そこを `Ctrl-G` が埋める。
最初から全リポジトリを `z` の対象にしたいときは一度だけ:

```sh
$ ghq list --full-path | while read -r d; do zoxide add "$d"; done
```

zoxide が場所を記録するのは**対話シェルで `cd` したとき (chpwd) だけ**。そのため次の移動は
学習に入らない (実測: 導入から 3 日でデータベースは 6 件だった)。

- 端末アプリのセッション復元などで**最初からそのディレクトリで開いたシェル** — `cd` が起きない。
- Claude Code の Bash での移動 (下の「direnv」を参照)。

プロンプトのたびに記録させる `programs.zoxide.flags = [ "--hook" "prompt" ]` もあるが、
長く居た場所ほど点数が上がり順位の付き方が変わる。現在は既定の `pwd` のまま。

### プロンプト

入力中と実行後で形が変わる。コマンドと実行結果を範囲選択してコピーしたとき、
プロンプトの装飾が混ざらないようにするため (`refine-prompt-transient`)。

```
dotfiles  feat/prompt-transient-zsh-default                          !1 +1 ?1   ← 入力中だけ出る状態行 (starship)
%                                                                                ← 入力行
```

実行すると状態行が消え、入力行が zsh の既定の表示 (`%n@%m %1~ %# `) に置き換わる。
失敗したときだけ、実行結果の直後に終了ステータスが残る。

```
user@host dotfiles % ls missing-file
ls: missing-file: No such file or directory
exit 1
user@host dotfiles % rg -n TODO . | head -3
exit 1|0                                    ← パイプは各段の値 (rg が 1、head が 0)
```

- 入力途中で Ctrl-C を押した行も同じ形に縮む。
- 状態行のユーザー名とホスト名は SSH のときだけ出る。
- 置き換えが効かなくなったと感じたら、対話シェルで `whence -w TRAPINT` を確認する。
  `function` でなければ、何かが `trap - SIGINT` で消している (direnv のフックがそうで、
  precmd のたびに定義し直して対処している)。

### direnv

`direnv` + `nix-direnv` は**使える状態にするところまでがこのリポジトリの担当**。各プロジェクトの
`.envrc` / `flake.nix` はそれぞれのリポジトリで管理する。`mise` を採らないのは、再現性の担保を
既に flake が持っており、入れるとランタイムの版の情報源が 2 箇所に分かれるため。

**direnv は Claude Code の Bash では発火しない** (実測)。Bash ツールは
`~/.claude/shell-snapshots/*.sh` を読んで起動するが、そのスナップショットは alias / setopt /
関数 / `PATH` しか保存せず、フックの登録先である `precmd_functions` / `chpwd_functions`
(配列) を復元しないため。エージェントに環境を渡したいときは明示実行する:

```sh
$ direnv exec . <cmd>
```

同じ理由で、**Claude が移動したディレクトリは `zoxide` の学習に入らない**。データベースは
所有者の移動だけを反映する。

### herdr

Claude Code / Codex を並べて動かすためのマルチプレクサ。ペインごとにエージェントの状態
(作業中 / 入力待ち / 完了) を一覧でき、detach しても動き続ける。**エージェント作業専用で、
tmux は置き換えない。**

- **tmux と入れ子にしない。** Ghostty のウィンドウ / タブ単位で使い分ける。prefix がどちらも
  `Ctrl-b` で、外側に食われる。ssh 越しの環境を読み直す仕組み (`tmux.nix`) も herdr には無い。
- **接続元の Mac から、接続先の Mac の herdr に接続して使える** (`herdr-remote-machines`)。
  前提として、利用側がその 2 台の間の agent 転送を宣言している。

  ```sh
  $ herdr machine add <host> --label <host>   # 接続元で一度だけ。以後は herdr の Ctrl-b w で切り替える
  $ herdr --remote <host>                      # 保存せずに 1 つだけ接続する
  ```

  接続し直した後も、ペイン (その中で動き続ける Claude Code を含む) の git の署名と push の承認は
  **接続元**に出る。herdr は起動時の `SSH_AUTH_SOCK` を持ち続けて再接続で更新しないため、herdr の
  ペインでは `SSH_AUTH_SOCK` を固定パス `~/.ssh/agent-forward.sock` にしてあり、ssh でログインする
  たびに `~/.ssh/rc` がその先を転送された agent に張り替える (先が生きている間は張り替えない)。
- **接続先の Mac の前で使う前に、接続元の herdr を終了する** (`Ctrl-b q`)。接続が残っていると、接続先の
  前で herdr のペインから行う署名の承認も接続元に出る。保存したマシンは、接続元の herdr が起動している
  間は Local を表示していても接続を保つ。接続元をスリープさせた場合は、約 1 分で接続先の側の接続が切れる
  (sshd の `ClientAliveInterval`)。
- **承認が無人の接続先に出たら、接続元の herdr から接続し直す。** リンクが herdr 以外の接続
  (直前の `ssh <host>` など) を指したまま、その接続が先に閉じた場合に起きる。
- ssh で相手の Mac に入って herdr を起動する使い方 (tmux と同じ使い方) はしない。
- **`herdr integration install claude` は実行しない。** `~/.claude/settings.json` は読み取り専用なので
  hook の追加は保存されず、hook のスクリプト (`~/.claude/hooks/herdr-agent-state.sh`) だけが宣言の外に
  残る。エージェントの状態は連携しなくても画面から判定される。

```sh
$ herdr                         # 起動 (サーバーが動いていれば再接続)
$ herdr server reload-config    # config.toml の変更を反映する (prefix+R でも可)
$ herdr agent explain w1:p1     # 状態の判定の根拠を見る (引数はペイン ID。agent list の pane_id)
$ herdr agent list              # 認識しているエージェントの一覧 (JSON)
```

起動時に新しい版を見つけるとログに出すが、**`herdr update` は使わない**。版は `flake.lock` で決める。

裏のタブのエージェントが完了・入力待ちになると、音に加えて Ghostty のデスクトップ通知が出る
(`ui.toast.delivery = "terminal"`)。接続先の herdr に attach しているときも、通知は接続元に出る。
初めての通知では macOS が Ghostty の通知を許可するか尋ねる。拒否した場合は、システム設定の「通知」で
Ghostty を許可する。

設定は `modules/common/terminal.nix` の `programs.herdr.settings` に書く (onboarding を飛ばす指定、
テーマ `tokyo-night`、通知)。switch すると herdr のサーバーが設定を読み直す。**設定画面 (`prefix+s`) で
apply しても何も起きない** — 書き込みに失敗して、いまのセッションにも反映されない (実測)。

## SSH

### sshd は公開鍵認証だけ

macOS のリモートログイン (sshd) は、**公開鍵だけ**を受け付ける。パスワードとキーボードインタラクティブ
認証は受け付けない (`modules/darwin/default.nix`)。リモートログインは接続中のすべてのネットワークで
22 番を開けるため、公衆 Wi-Fi 上に持ち出した Mac にも第三者が到達できる。

- ログインを許す鍵は利用側が宣言する (`users.users.<user>.openssh.authorizedKeys`)。
- **リモートログインのオン / オフは宣言していない。** GUI (システム設定 → 一般 → 共有) で
  切り替える。宣言すると switch のたびに巻き戻る。

適用後、または macOS を更新した後に実効値を確認する:

```sh
$ sudo sshd -T | grep -E 'passwordauth|kbdinteractive|authenticationmethods'
passwordauthentication no
kbdinteractiveauthentication no
authenticationmethods publickey
```

### 入った先での git の操作と署名

利用側が所有者の Mac 同士の agent 転送を宣言していれば、入った先の `git pull` / `git push` と
コミット署名は転送された agent を使い、**1Password の承認は接続元に出る**。

- 転送された agent を使うのは、次のどちらかのとき。そのときは 1Password の `Match` ブロック
  (`modules/common/ssh.nix`) の `IdentityAgent` が適用されず、署名は `ssh-keygen` が行う
  (`modules/common/git.nix`)。TTY なしの実行 (`ssh <host> 'git -C … fetch'`) でも同じ。
  - `SSH_CONNECTION` があり、`SSH_AUTH_SOCK` のソケットが実在する (ssh 越しのシェル。tmux は detach で
    環境を戻さないので、切断後の古い値はソケットの有無で見分ける)
  - `SSH_AUTH_SOCK` が `~/.ssh/agent-forward.sock` で、その先が実在する (herdr のペイン。上の herdr の節)
- 転送中は、接続先の同じユーザーのプロセスが接続元の鍵を使える (1Password は承認をアプリ単位で覚える)。
  だから転送は所有者の端末に限る。
- tmux の既存ペインは、attach またはセッションの切り替えの後の最初のコマンドの前に `SSH_AUTH_SOCK` /
  `SSH_CONNECTION` を読み直す (`modules/common/tmux.nix`)。attach し直した側の Mac の
  1Password が使われる。既に動いている tmux サーバーでは、
  `tmux source-file ~/.config/tmux/tmux.conf` で設定を読み直すまで効かない。
- **attach し直す前から動いているプロセス (エディタ、Claude Code など) は古い環境のまま。**
  attach し直した後に起動し直す。
  - 接続先の Mac の前で起動したものを接続元から使うと、承認が接続先に出る。
  - 接続元から attach 中に起動したものは、切断後は接続先の 1Password に戻る。
- 接続元がスリープして応答しなくなると、接続が切れるまで転送先が選ばれ、git の操作が待たされる。
  sshd は応答しない接続を約 1 分 (15 秒 × 4 回) で切る (`modules/darwin/default.nix`)。
- 同じ Mac のローカルと ssh 越しの両方から、10 秒以内に続けて相手の Mac へ ssh すると、
  多重化接続の相乗りで、先の接続が転送した agent が使われることがある (10 秒で戻る)。

## 保存されない操作

アプリ自身の設定画面での変更は保存されない。**どれもエラーにならず黙って消える**ので注意する。

| 操作 | 挙動 | 恒久的に変えるには |
|---|---|---|
| Claude Code の `/config`・`/theme` | そのセッションだけ効き、次の起動で戻る | `modules/common/claude-code.nix` の `settings` |
| Claude Code の権限の「常に許可」 | 同上 | 同上 (`permissions.allow`) |
| Claude Code のプラグインの有効 / 無効 | 同上 | 同上 (`enabledPlugins`) |
| herdr の設定画面 (`prefix+s`) | **いまのセッションにも反映されない** | `modules/common/terminal.nix` の `programs.herdr.settings` |

実測したのは `/theme` と herdr の設定画面。Claude Code のほかの 2 つは同じ `settings.json` への
書き込みで、読み取り専用のときは「そのセッション限り」になると公式ドキュメントにある。

Claude Code は `~/.claude/settings.json` を読み取り専用のまま扱い、ファイルを置き換えない
(実測: 変更後も store への symlink のまま)。ユーザー単位の `settings.local.json` は存在しないので、
書き込める逃げ道はプロジェクト単位の設定 (`.claude/settings.local.json`) だけ。

## `darwin-rebuild` について

**`darwin-rebuild` は呼び出し側の PATH に依存しない。** スクリプトが冒頭で自分の `PATH` を上書きし、
`coreutils` / `jq` / `git` / `nix` を store と `/nix/var/nix/profiles/default/bin` から解決する。
だから `sudo` が PATH をどう扱うかは関係なく、**世代がひとつでもあれば安定した絶対パスで必ず動く**:

```sh
$ sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .#<host>
```

対話シェルでは `/run/current-system/sw/bin` が PATH に入っている (`/etc/zshenv` が nix-darwin の
`set-environment` を読む) ので、通常は `sudo darwin-rebuild ...` で足りる。

**`darwin-rebuild` が本当に存在しないのは、そのマシンに nix-darwin の世代がまだ 1 つも無い初回だけ**
(`/run/current-system` が無い状態)。その場合は利用側のリポジトリで
`nix build .#darwinConfigurations.<host>.system` → `sudo ./result/sw/bin/darwin-rebuild switch --flake .#<host>`
を使い、終わったら `result` を消す。

いずれの場合も `sudo nix run nix-darwin -- switch` で代替しないこと。
**registry 解決で nix-darwin の master を取るため `flake.lock` の pin から外れる。**
