# terminal-tooling Specification

## Purpose
端末のツール (シェル、差分の表示、移動、プロンプト、マルチプレクサ) の選び方と宣言のしかた。人間と非対話のエージェントが同じシェル構成を共有することを前提にする。

## Requirements
### Requirement: 対話シェル向けの変更を非対話実行へ波及させない

システムは、対話シェルの体験を変えるための設定が、**非対話で実行されるエージェント (Claude Code 等) のコマンド実行結果を変えてはならない** (MUST NOT)。

この端末は人間と非対話エージェントが同じシェル構成を共有する。`programs.zsh.shellAliases` の宣言は Claude Code のシェルスナップショット (`~/.claude/shell-snapshots/*.sh`) にそのまま載るため、既存コマンド名を置き換える alias はエージェントの実行に波及する。スナップショットは関数も保存するため、**関数名そのものが特別な意味を持つ関数 (`TRAPINT` などのシグナルトラップ) も同様に波及しうる**。

#### Scenario: 置き換え系ツールの導入

- **WHEN** `eza` / `bat` のような既存コマンドの代替ツールを導入する
- **THEN** ツールは自身の名前で `PATH` に置く
- **AND** `ls` / `cat` など既存コマンド名を乗っ取る alias を宣言しない

#### Scenario: 差分表示ツールの設定経路

- **WHEN** git の差分表示を人間向けに変更する
- **THEN** 出力が TTY でない場合に git が自動的に無効化する経路 (ページャ機構 — `core.pager` または `pager.<コマンド>`) を用いる
- **AND** TTY と無関係に起動する経路 (`diff.external` / `GIT_EXTERNAL_DIFF` の恒久設定) を既定にしない
- **AND** 後者を使いたい場合は git alias として明示的に呼ぶ形にする

#### Scenario: シグナルトラップ関数の定義

- **WHEN** 対話シェル向けの処理のために `TRAPINT` などのトラップ関数を `initContent` で定義する
- **THEN** Claude Code のシェルスナップショットにその関数が載った状態で、非対話シェルが SIGINT を受けたときの終了コードと出力が、定義しない場合と同じであることを実測で確認している
- **AND** 同じでない場合は、非対話シェルで定義されない形 (対話シェルの条件の中での定義、または関数として保存されない `trap` 構文) に改める

### Requirement: 端末ツールは native モジュールで宣言する

システムは、導入する端末ツールに home-manager の `programs.*` native モジュールが存在する場合、それを用いて宣言しなければならない (SHALL)。`programs.zsh.initContent` に初期化コード (`eval "$(<tool> init zsh)"` 等) を手書きしてはならない (MUST NOT)。

native モジュールはシェル統合の有効化・設定ファイルの生成・依存パッケージの追加をまとめて行うため、手書きの初期化はそれらを二重化し、`home.packages` と `initContent` に情報源が分かれる。

**native モジュールが対象シェルで提供しない機能を補う記述は、初期化の手書きにあたらない。** その場合は、提供されないことの根拠と補う理由をコメントに残し、`initContent` 内の順序を `lib.mkOrder` でツールの初期化より後に固定しなければならない (SHALL)。

#### Scenario: native モジュールがあるツールの導入

- **WHEN** `fzf` / `zoxide` / `direnv` / `starship` / `bat` のように `programs.<tool>` が存在するツールを導入する
- **THEN** `programs.<tool>.enable = true` で宣言する
- **AND** 同じツールを `home.packages` に重複して列挙しない
- **AND** `initContent` に初期化の `eval` を書かない

#### Scenario: native モジュールが無いツールの導入

- **WHEN** `programs.<tool>` が存在しないツールを導入する
- **THEN** `home.packages` に宣言する
- **AND** シェル統合が必要な場合に限り、その理由をコメントに残したうえで `initContent` に記述する

#### Scenario: native モジュールが対象シェルで提供しない機能の補完

- **WHEN** native モジュールのオプションが対象シェルでは無効な機能 (例: `programs.starship.enableTransience` は fish 専用) を zsh で使いたい
- **THEN** 補う記述を `initContent` に置き、`lib.mkOrder` でツールの初期化より後に固定する
- **AND** オプションが対象シェルで無効であることの根拠 (モジュールの説明文など) をコメントに記録する
- **AND** ツールの初期化そのもの (`eval "$(<tool> init zsh)"`) は手書きしない

### Requirement: 暗黙の外部依存を宣言に引き上げる

システムは、リポジトリが管理するスクリプト・設定が実行時に依存するコマンドを、**Nix 構成で宣言**しなければならない (SHALL)。OS 同梱のコマンドが偶然 `PATH` に存在することに依存してはならない (MUST NOT)。

`/usr/bin` に存在するコマンドは flake の pin の外にあり、OS の更新で版が変わっても構成は何も検知しない。

#### Scenario: 管理下スクリプトの依存

- **WHEN** `claude/statusline-command.sh` のような管理下のスクリプトが外部コマンドを呼ぶ
- **THEN** そのコマンドが `home.packages` または `programs.*` により宣言されている
- **AND** そのコマンドの解決先が Nix プロファイル配下であることを確認できる

#### Scenario: 環境変数が指すコマンド

- **WHEN** `EDITOR` のような環境変数でコマンドを指定する
- **THEN** 指定先は Nix 構成が宣言したコマンドである

### Requirement: 端末ツールの導入根拠を実際の作業に置く

システムは、端末ツールを「一般に推奨されているから」という理由で導入してはならない (MUST NOT)。この端末で実際に行われている作業 (エージェントが生成した差分を読む、リポジトリ間を移動する等) に紐づく根拠を持たなければならない (SHALL)。

#### Scenario: ツール選定の記録

- **WHEN** 端末ツールを新たに宣言する
- **THEN** そのツールが解決する具体的な作業がコメントまたは `design.md` に記録されている

### Requirement: プロジェクト環境の自動切替を使えるようにする

システムは、ディレクトリに応じて開発環境を切り替える機構 (`direnv` + `nix-direnv`) を宣言しなければならない (SHALL)。ただし各プロジェクトの `.envrc` / `flake.nix` はこのリポジトリの管理対象ではない。

#### Scenario: 機構の提供範囲

- **WHEN** `direnv` を導入する
- **THEN** このリポジトリは `programs.direnv` と `nix-direnv` の有効化までを行う
- **AND** 個別プロジェクトの `.envrc` / `flake.nix` はそれぞれのリポジトリで管理する

#### Scenario: 非対話エージェントでの挙動の確認

- **WHEN** `direnv` を導入して `switch` した
- **THEN** 非対話エージェントのシェルでフックが発火するかを実測して記録する
- **AND** 発火しない場合は、明示実行 (`direnv exec .`) が代替として使えることを記録する

### Requirement: プロンプトは実行ログに状態表示を残さない

システムは、コマンドを実行した後のスクロールバックに、**入力中にだけ意味を持つ状態表示** (状態行・右側の表示) を残してはならない (MUST NOT)。実行した行は、実行した場所と直前の結果が分かる形でなければならない (SHALL)。

コマンドと実行結果を範囲選択してコピーしたとき、プロンプトの装飾が混ざらないようにするため。入力中の状態表示 (git の状態など) は、入力している間だけ必要になる。

- 入力中: 1 行目に状態行、2 行目に記号だけの入力行
- 実行後: 状態行と右側の表示を消し、入力行を `ユーザー名@ホスト名 ディレクトリ名 記号 コマンド` (zsh の `%n@%m %1~ %# `) に置き換える
- 記号は zsh の `%#` (通常 `%`、特権時 `#`) とし、色は付けない
- 失敗したときは、実行結果の直後に終了ステータスを文字で 1 行残す。パイプでは各段の値を並べる

#### Scenario: 成功したコマンドの実行ログ

- **WHEN** 対話 zsh で `git status -s` を実行して成功する
- **THEN** スクロールバックには `<ユーザー名>@<ホスト名> <ディレクトリ名> % git status -s` と実行結果だけが残る
- **AND** 状態行と右側の表示は残らない

#### Scenario: パイプの途中が失敗したコマンド

- **WHEN** `rg -n TODO . | head -3` を実行し、`rg` が 1、`head` が 0 で終わる
- **THEN** 実行結果の直後に `exit 1|0` の行が残る
- **AND** 記号の色は変わらない

#### Scenario: 入力途中の中断

- **WHEN** コマンドを入力している途中で Ctrl-C を押す
- **THEN** スクロールバックには実行後と同じ形の行 (`%n@%m %1~ %# 入力途中の文字列`) だけが残る
- **AND** 状態行と右側の表示は残らない

#### Scenario: ディレクトリの移動

- **WHEN** `cd modules/common` を実行した後に次のコマンドを実行する
- **THEN** 次のコマンドの実行ログには、移動先のディレクトリ名 (`common`) が入る

### Requirement: エージェント作業用マルチプレクサは tmux と入れ子にしない

システムは、エージェント作業用のマルチプレクサ (herdr) を tmux と併用する場合、どちらかをもう一方のペインの中で起動する構成を前提にしてはならない (MUST NOT)。両者は端末エミュレータのウィンドウ / タブ単位で使い分けなければならない (SHALL)。

herdr と tmux は既定の prefix が同じで、ssh 越しの環境を読み直す仕組みも tmux 側にしかないため、入れ子にすると操作とエージェントの実行環境の両方が曖昧になる。

#### Scenario: herdr の起動経路

- **WHEN** herdr を導入する
- **THEN** zsh / 端末エミュレータに tmux や herdr を自動起動する設定が無い
- **AND** herdr と tmux の設定に、入れ子を前提にした prefix の変更が無い

#### Scenario: herdr の設定ファイルの配置

- **WHEN** herdr の `config.toml` をリポジトリで管理する
- **THEN** その内容は `programs.herdr.settings` の宣言から生成される
- **AND** herdr 自身による書き込み (onboarding、設定画面) は保存されないことが文書に書かれている

### Requirement: マルチプレクサの連携で Claude Code の設定を宣言外に変更しない

システムは、マルチプレクサの連携コマンド (`herdr integration install claude` 等) によって、`~/.claude/settings.json` や `~/.claude/hooks/` を宣言外で変更してはならない (MUST NOT)。連携が必要な場合は、追加される hook とスクリプトをリポジトリで管理する変更として行わなければならない (SHALL)。

`~/.claude/settings.json` は宣言から生成した読み取り専用の実体なので、連携コマンドによる hook の追加は保存されず、hook スクリプトだけが宣言外に残る (`retire-out-of-store-symlinks`)。

#### Scenario: herdr 導入直後の Claude Code 設定

- **WHEN** herdr を導入して switch した
- **THEN** `programs.claude-code.settings` (`modules/common/claude-code.nix`) に herdr の hook が含まれない
- **AND** `~/.claude/hooks/herdr-agent-state.sh` が存在しない

### Requirement: マルチプレクサの複数マシン機能は、再接続の後も承認を接続元で行える構成で使う

システムは、マルチプレクサ (herdr) で別の所有者の Mac に接続して使う場合、接続し直した後も、そのペインで行う git の署名・GitHub 認証の承認を **操作している側の Mac** で求めなければならない (SHALL)。接続前から動いているペインと、その中で動き続けるプロセス (Claude Code など) も対象とする。

以下、herdr で接続する側の所有者の Mac を**接続元**、接続される側を**接続先**と呼ぶ。

herdr のサーバーは起動時の `SSH_AUTH_SOCK` を持ち続け、再接続で更新しない (herdr 0.9.1 時点)。そのため herdr のペインでは、`SSH_AUTH_SOCK` を接続ごとに張り替える固定パスにしなければならない (SHALL)。herdr を更新したときは、再接続の後の承認先を確かめ直さなければならない (SHALL)。

#### Scenario: 接続元から接続し直した後の既存ペイン

- **WHEN** 接続元から接続先の herdr に接続してペインで Claude Code を起動し、接続元の herdr を終了してから、接続元から再び接続する
- **THEN** 既存のペイン、新しいペイン、動き続けている Claude Code のいずれでも、署名と GitHub 認証の承認が接続元に出る

#### Scenario: 接続先の前で起動したサーバーへの接続

- **WHEN** 接続先の前で起動した herdr のサーバーに、接続元から接続する
- **THEN** そのペインでの署名と GitHub 認証の承認が接続元に出る

#### Scenario: 接続元の herdr を終了した後の接続先での操作

- **WHEN** 接続元の herdr を終了し、接続元から接続先への ssh 接続が残っていない
- **AND** 接続先の前で herdr に接続し、ペインで署名と GitHub 認証を行う
- **THEN** 承認は接続先に出る

