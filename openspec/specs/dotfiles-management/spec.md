# dotfiles-management Specification

## Purpose
dotfiles を home-manager で宣言的に管理するときの原則。設定ファイルは宣言から生成して実体との乖離を作らず、秘密を store に置かず、環境固有の値と私的な情報をこのリポジトリに書かない。

## Requirements
### Requirement: dotfiles は home-manager で宣言的に管理する

システムは、ユーザーの dotfiles を home-manager を通じて宣言的に管理しなければならない (SHALL)。移行完了後、chezmoi と `dot_*` / `private_dot_*` ファイルを情報源として使用してはならない (MUST NOT)。

#### Scenario: switch による dotfiles 配置

- **WHEN** `darwin-rebuild switch` を実行する
- **THEN** home-manager が管理する dotfiles がホームディレクトリに配置される

### Requirement: 主要設定は native モジュールで表現する

システムは、zsh・git・tmux の設定を home-manager の `programs.*` native モジュール (`programs.zsh` / `programs.git` / `programs.tmux`) で表現しなければならない (SHALL)。

**新たに導入する端末ツールについても、対応する `programs.*` native モジュールが存在する場合はそれを用いなければならない (SHALL)。** `programs.zsh.initContent` にシェル統合の初期化コードを手書きして代替してはならない (MUST NOT)。手書きは情報源を `home.packages` と `initContent` に分割し、native モジュールが行う設定ファイル生成・依存追加を二重化する。

移行前から引き継ぐ挙動 (zsh の alias・history 設定、git の 1Password `op-ssh-sign` 署名設定、ghq root など) を保持しなければならない (SHALL)。**ただしリモートへ設定を転送する `ssh` 関数はこの対象から外す** — 同じ spec の「リモートホストの環境を転送で同期してはならない」が禁じる挙動であり、保持すべき挙動ではない。

**プロンプトの定義元を 2 つにしてはならない (MUST NOT)。** プロンプトの定義をツールへ移譲する場合は、移譲元の宣言を削除しなければならない (SHALL)。`programs.starship` と、starship と無関係にプロンプトの内容を定義する `PROMPT=` を同時に宣言してはならない (MUST NOT) — 生成された `.zshrc` の後勝ちに依存する状態になる。

**移譲先のツールの出力を包む記述は、定義元の二重化にあたらない。** native モジュールが対象シェルで提供しない機能 (例: zsh での transient prompt) を補うために `PROMPT` / `RPROMPT` を操作する場合は、次をすべて満たさなければならない (SHALL)。

- 操作の起点が、ツール自身が代入した `PROMPT` / `RPROMPT` の値である (その値を控え、戻す)
- `initContent` 内の順序を `lib.mkOrder` で明示し、ツールの初期化より後であることを評価時に保証する
- ツールの初期化が行われない条件 (`TERM=dumb` 等) では何もしない
- 補う理由と、native モジュールが提供しないことの根拠をコメントに残す

プラットフォーム固有の記述は、シェルの実行時分岐ではなく**構成の評価時に**分岐させなければならない (SHALL)。

#### Scenario: zsh 設定の移植

- **WHEN** `programs.zsh` で alias・history オプションを宣言して `switch` する
- **THEN** 生成された `.zshrc` が移行前の挙動を再現する
- **AND** 生成物に、リモートへ設定を転送する関数は含まれない
- **AND** 生成物に、プラットフォームを実行時に判定する分岐は含まれない

#### Scenario: git 署名設定の保持

- **WHEN** `programs.git` で 1Password の `op-ssh-sign` を用いた SSH 署名を宣言する
- **THEN** 生成された git 設定で従来どおり署名付きコミットが可能である

#### Scenario: 端末ツールの追加

- **WHEN** `fzf` / `zoxide` / `direnv` / `starship` / `bat` のように native モジュールを持つツールを追加する
- **THEN** `programs.<tool>` で宣言されている
- **AND** `initContent` に当該ツールの初期化コードが含まれない

#### Scenario: プロンプト定義の移譲

- **WHEN** `programs.starship` を有効化する
- **THEN** `initContent` から、starship と無関係にプロンプトの内容を定義する `PROMPT=` の宣言が削除されている
- **AND** 生成された `.zshrc` で、starship の初期化より前に `PROMPT=` の代入が行われていない

#### Scenario: ツールの出力を包むプロンプトの補完

- **WHEN** starship が zsh に提供しない transient prompt を `initContent` で補う
- **THEN** 補う記述は starship が代入した `PROMPT` / `RPROMPT` を控えてから操作する
- **AND** 補う記述は `lib.mkOrder` により、生成された `.zshrc` 上で starship の初期化より後に置かれている
- **AND** `TERM=dumb` のように starship が初期化されない条件では、`PROMPT` / `RPROMPT` を変更しない
- **AND** 補う理由 (home-manager の `enableTransience` が fish 専用であること) がコメントに記録されている

### Requirement: 秘密情報を Nix store に置かない

システムは、秘密鍵・トークン等の秘密情報を Nix store (world-readable) に配置してはならない (MUST NOT)。SSH の `config`/`config.d/` は秘密鍵を含まず署名を 1Password に委譲しているため、home-manager で管理してよい (MAY)。

#### Scenario: SSH 設定の安全な管理

- **WHEN** ssh の `config`/`config.d/` を home-manager で管理する
- **THEN** 秘密鍵は含まれず、署名は 1Password の `op-ssh-sign` に委譲されたままである

### Requirement: 管理下の設定は実際に参照されていなければならない

システムは、リポジトリで管理し `$HOME` 配下へ配置している設定ファイル・スクリプトが、**実際に対象アプリケーションから参照されている**状態を保たなければならない (SHALL)。配置されているが、どの設定からも参照されていないファイルを管理下に残してはならない (MUST NOT)。参照されなくなった場合は、参照を復元するか、管理対象から削除する。

#### Scenario: 参照されていない管理ファイルの検出

- **WHEN** リポジトリ実体を `$HOME` 配下へ symlink しているファイルがある
- **THEN** そのファイルを参照する設定 (アプリの設定ファイル内のパス指定等) が存在することを確認できる
- **AND** 参照が存在しない場合は、配線を復元するか管理対象から外す

### Requirement: アプリケーション自身が書き込む設定ファイルの扱い

システムは、アプリケーション自身が実行中に書き込む設定ファイルであっても、**宣言から生成しなければならない** (SHALL)。アプリケーションによる書き込みを保存するために、書き込み可能な形式で配置してはならない (MUST NOT)。宣言が唯一の情報源であり、アプリ側で行った変更は保存されない。

この性質は利用者から見て分かりにくい (エラーは出ず、その場限りで効くアプリ (Claude Code) と、その場でも効かないアプリ (herdr の設定画面) がある) ため、**どのアプリのどの操作が保存されないのかを文書に明示しなければならない** (SHALL)。

#### Scenario: 書き込みが発生する設定ファイルの配置

- **WHEN** 対象アプリケーションが自身の設定ファイルへ値を書き込む
- **THEN** そのファイルは宣言から生成された読み取り専用の実体である
- **AND** アプリケーションの変更は保存されず、恒久的な変更はリポジトリの宣言で行う

#### Scenario: 保存されない操作の周知

- **WHEN** アプリ自身が書き込む設定ファイルを管理下に置く
- **THEN** そのアプリのどの操作が保存されないのかが README に書かれている
- **AND** 恒久的に変えるための手順 (宣言の変更と `switch`) が併記されている

### Requirement: プラットフォーム固有の外部パスを無条件な事実として書かない

システムは、プラットフォームによって位置が異なる外部プログラムやソケットのパスを、**全ホストに無条件で適用される設定として書いてはならない** (MUST NOT)。対象には、署名に用いる外部プログラムのパス (`op-ssh-sign`、`/usr/bin/ssh-keygen`、署名鍵を選ぶコマンドが使う `/usr/bin/ssh-add`) と、ssh の認証エージェントのソケットパスを含む。

これらのパスは、**その機能を使うかどうかを表す単一の boolean option で gate された 1 か所に閉じなければならない** (SHALL)。**パスそれ自体を option にしてはならない** (MUST NOT) — パスは定数であり、定数を option に置き換えても指し先が増えるだけで何も表現しないため (`multi-host-configuration` の「option を作る根拠」と同じ理由)。gate の boolean は、既定値をプラットフォームから導出するため option として正当である。

複数のモジュールが同じパスを使う場合 (1Password の agent のソケットを ssh の設定と署名鍵を選ぶコマンドが使うなど)、パスの値は、モジュールではなく値だけを返す 1 つの .nix ファイルに置き、各モジュールがそれを読み込まなければならない (SHALL)。値を定義する場所が gate の外にあっても、生成物に現れるのは gate の内側で使った分だけでなければならない (SHALL)。モジュール間で受け渡すために internal の option にしてはならない (MUST NOT) — 定数であり、`multi-host-configuration` の internal の例外 (導出した値の受け渡し) に当たらない。

当該プログラムを利用しないホストでは、その設定自体を出力してはならない (MUST NOT)。

#### Scenario: 署名プログラムのパス

- **WHEN** git の署名に外部プログラムを用いる
- **THEN** そのパスは boolean option で gate された分岐の内側にのみ現れる
- **AND** macOS のアプリケーションバンドル内のパスが、無条件な設定として出力されることはない

#### Scenario: 認証エージェントのソケット

- **WHEN** ssh の認証エージェントのソケットを指定する
- **THEN** そのソケットを指す設定は、gate が有効なホストの生成物にのみ現れる

#### Scenario: 複数のモジュールが使うパス

- **WHEN** ssh の設定と署名鍵を選ぶコマンドが、1Password の agent のソケットのパスを使う
- **THEN** パスの値は値だけを返す 1 つの .nix ファイルにあり、両方のモジュールがそれを読み込んでいる
- **AND** パスを値に持つ option (internal を含む) は無い

#### Scenario: 利用しないホストでの無効化

- **WHEN** 当該の外部プログラムを使わないホストとして構成を評価する
- **THEN** その設定は生成される構成に含まれない
- **AND** 存在しないパスを指す設定が残らない
- **AND** ssh の設定は、ファイルを配置しないことで当該設定が存在しない状態を作る (ディレクトリ単位のリンクでは表現できない)

#### Scenario: リンク対象の列挙を手で保守しない

- **WHEN** ファイル単位で symlink する対象が glob で読み込まれるディレクトリ (`ssh/config.d/*.conf`) である
- **THEN** リンク対象はリポジトリの中身から導出される
- **AND** 新しいファイルを追加したときに宣言側の列挙を書き足す必要がない
- **AND** 列挙漏れによって設定が黙って配備されない状態が起こらない

#### Scenario: 導出はリポジトリのソースを読む

- **WHEN** リンク対象をリポジトリの中身から導出する
- **THEN** 読まれるのは flake のソース (git が追跡しているもの) であり、作業ツリーではない
- **AND** **新しいファイルは追跡下に入れてから適用する必要がある**ことが文書に明記されている

### Requirement: リモートホストの環境を転送で同期してはならない

システムは、リモートホストのシェル設定を、接続時のファイル転送によって同期してはならない (MUST NOT)。リモートホストの環境は、そのホスト自身の宣言的な構成によって管理しなければならない (SHALL)。

#### Scenario: 接続時の転送を行わない

- **WHEN** リモートホストへ接続する
- **THEN** ローカルの設定ファイルがリモートへ転送されない
- **AND** リモートの既存の設定が上書きされない

#### Scenario: リモート環境を揃えたい場合

- **WHEN** リモートホストのシェル環境を揃えたくなる
- **THEN** そのホストを対象に含める価値があるかを先に判断する
- **AND** 対話的に使われていないホストには、設定を持ち込まないことを選ぶ

### Requirement: 設定は宣言から生成し、実体との乖離を作らない

システムは、`$HOME` 配下へ配備する設定の実体を、**宣言から生成しなければならない** (SHALL)。リポジトリの作業ツリーを指す out-of-store symlink (`config.lib.file.mkOutOfStoreSymlink`) を使ってはならない (MUST NOT)。

宣言がその設定の唯一の情報源であり、手元での編集や rebuild を経ない反映を前提にしてはならない (MUST NOT)。設定を変えるときはリポジトリを変更し、`switch` で反映する。

out-of-store symlink が理由で存在していた機構 (activation 前の防御、リンク先ディレクトリの一覧、`builtins.readDir` による配備対象の導出、ファイル名の一致による出し分けとその `assertions`) は、リンクの撤去と同時に撤去しなければならない (SHALL)。ただし撤去は、**古いリンクが実機から無くなったことを確認した後**に行わなければならない (SHALL)。

#### Scenario: 設定ファイルの配置

- **WHEN** アプリ固有形式の設定ファイル (端末、ssh、エージェント等) を管理下に置く
- **THEN** その内容は `programs.*` の native モジュールまたは `home.file` の既定 (store への読み取り専用コピー) で生成される
- **AND** 配置された実体は Nix store を指し、リポジトリの作業ツリーを指さない

#### Scenario: 実行可能なスクリプトの配置

- **WHEN** エージェントのステータスラインのような実行可能スクリプトを配置する
- **THEN** スクリプトは宣言から生成され (`pkgs.writeShellScript` 等)、実行可能属性を持つ
- **AND** それを参照する設定は、生成されたスクリプトの絶対パスを指す

#### Scenario: 古いリンクが残った状態での適用

- **WHEN** out-of-store symlink から宣言による生成へ移行する
- **THEN** 適用の前に、対象の祖先ディレクトリが symlink でないことと、対象が現行世代の home-manager が張ったファイル単位のリンクであることを確認している (その場合、古いリンクは home-manager が世代の差分として撤去する。手で先に消さない)
- **AND** 生成された実体で動いていることを実機で確認するまで、activation 前の防御機構を外さない

### Requirement: 環境固有の値と私的な情報を書かない

このリポジトリは公開されている。システムは、環境固有の値 (ユーザー名、git の identity、署名鍵とそれを指す名前、ssh の接続先、特定の環境でだけ使うパッケージ) を持ってはならない (MUST NOT)。値は利用側が与える。

また、利用側の私的な情報 (ホスト名、ドメイン、アドレス、ネットワークやクラスタの構成) を、コード、コメント、コミットメッセージ、ブランチ名、PR と issue の文章のいずれにも書いてはならない (MUST NOT)。実測の記録は、役割の名前 (接続元の Mac、接続先の Mac、所有者の端末) で書かなければならない (SHALL)。

core のモジュールが利用側の宣言に頼る場合は、その前提を利用側が与えるものとして文書に書かなければならない (SHALL)。

#### Scenario: 実測の記録を書く

- **WHEN** 2 台の Mac の間で振る舞いを実測し、その結果をコメントや要件に書く
- **THEN** ホスト名ではなく、接続元・接続先のような役割の名前で書かれている

#### Scenario: 利用側の宣言に頼る設定

- **WHEN** core の設定が、利用側が導入するアプリやフォント、利用側の転送の宣言を前提にする
- **THEN** その前提が core の README の「利用側が与えるもの」に書かれている

### Requirement: 署名鍵は利用側が与える名前で agent から選ぶ

システムは、git の署名に使う公開鍵を受け取る option を持ってはならず、生成する git の設定に公開鍵の文字列 (`user.signingkey`) を書いてはならない (MUST NOT)。鍵の実体は 1Password が管理し、利用側は鍵を指す名前 (1Password の項目名) だけを `dotfiles.git.signingKeyName` で与える。1Password の SSH agent は項目名を鍵のコメントとして返し、項目名を変えるとコメントも変わる。

git は署名のたびに agent の鍵の一覧を取り、コメントが名前と完全に一致する鍵がちょうど 1 本のときだけ、それを署名鍵にしなければならない (SHALL)。部分一致・前方一致で選んではならず、agent の鍵の本数や並び順に依存してはならない (MUST NOT)。別の鍵で署名してはならない (MUST NOT)。

次のいずれかでは、署名を中止し、名前とどの場合かが分かるメッセージを出さなければならない (SHALL)。(1) 一致する鍵が無い (agent に鍵が 1 本も無い場合を含む)。(2) 一致する鍵が 2 本以上ある。(3) agent に接続できない。メッセージは、どの agent (その Mac の 1Password か、転送された agent か) を見たかを示し、`user.signingkey` を設定して回避しないよう案内しなければならない (SHALL)。

`dotfiles.git.signingKeyName` と、利用側が直接書いた `user.signingkey` が同時にある構成は、評価に失敗しなければならない (SHALL)。git は `user.signingkey` があると名前による選択を黙って使わなくなるためである。

鍵を選ぶために、実行時に `op` CLI を使ってはならない (MUST NOT)。`op` はサインインの状態に依存し、ssh 越しでは接続先の 1Password に問い合わせるためである。

名前が与えられないとき (`null`)、または `dotfiles.onePassword.enable` が false のときは、署名の設定を出力してはならない (MUST NOT)。名前に空文字列を与えてはならない (MUST NOT)。公開鍵を与える旧来の option (`dotfiles.git.signingKey`) は存在してはならず、与えた構成は、移行先を示すメッセージとともに評価に失敗しなければならない (SHALL)。

#### Scenario: 名前に一致する鍵が 1 本

- **WHEN** 利用側が `dotfiles.git.signingKeyName` に 1Password の項目名を与え、手元で署名付きコミットを行う
- **THEN** その項目の鍵で署名され、1Password の承認はその Mac に出る
- **AND** 生成された git の設定に `user.signingkey` が無く、`gpg.ssh.defaultKeyCommand` がある

#### Scenario: 一致する鍵が先頭にない

- **WHEN** agent の一覧で、名前が違う鍵が名前の一致する鍵より前に並んでいる状態で署名付きコミットを行う
- **THEN** 名前の一致する鍵で署名される

#### Scenario: 空白を含む項目名

- **WHEN** 項目名が空白を含み、その名前を `dotfiles.git.signingKeyName` に与えて署名付きコミットを行う
- **THEN** その項目の鍵で署名される

#### Scenario: 名前を先頭に含む別の鍵だけがある

- **WHEN** agent に、コメントが `<名前>-old` の鍵だけがあり、コメントが `<名前>` の鍵が無い状態で署名付きコミットを行う
- **THEN** 一致する鍵が無いことを示すメッセージが出て、コミットは作られない

#### Scenario: 名前に一致する鍵が無い

- **WHEN** agent に、コメントが名前と一致する鍵が無い状態で署名付きコミットを行う
- **THEN** 名前と、一致する鍵が無いことと、見た agent を示すメッセージが出て、コミットは作られない
- **AND** メッセージは `user.signingkey` を設定しないよう案内する

#### Scenario: 名前が曖昧

- **WHEN** agent に、コメントが名前と一致する鍵が 2 本以上ある状態で署名付きコミットを行う
- **THEN** 名前と、一致する鍵が複数あることを示すメッセージが出て、コミットは作られない
- **AND** どちらの鍵でも署名されない

#### Scenario: agent に接続できない

- **WHEN** 手元で 1Password が起動しておらず、agent のソケットに接続できない状態で署名付きコミットを行う
- **THEN** 名前と、その Mac の 1Password の agent に接続できないことを示すメッセージが出て、コミットは作られない

#### Scenario: user.signingkey との併用

- **WHEN** 利用側が `dotfiles.git.signingKeyName` を与え、`programs.git.settings.user.signingkey` も書いて構成を評価する
- **THEN** 評価は失敗し、`user.signingkey` を消すよう案内するメッセージが出る

#### Scenario: 名前を与えない利用側

- **WHEN** 利用側が `dotfiles.git.signingKeyName` を与えない
- **THEN** 生成された git の設定に `commit.gpgsign`・`gpg.format`・`gpg.ssh.program`・`gpg.ssh.defaultKeyCommand` のいずれも入らない
- **AND** コミットは署名されずに成功する

#### Scenario: 1Password を使わないホスト

- **WHEN** `dotfiles.onePassword.enable` が false のホストで、`dotfiles.git.signingKeyName` を与えて構成を評価する
- **THEN** 生成された git の設定に `commit.gpgsign`・`gpg.format`・`gpg.ssh.program`・`gpg.ssh.defaultKeyCommand` のいずれも入らない

#### Scenario: 空の名前

- **WHEN** 利用側が `dotfiles.git.signingKeyName` に空文字列を与えて構成を評価する
- **THEN** 評価は失敗する

#### Scenario: 旧来の option を与えた利用側

- **WHEN** 利用側が `dotfiles.git.signingKey` を与えて構成を評価する
- **THEN** 評価は失敗し、`dotfiles.git.signingKeyName` へ移すよう案内するメッセージが出る
