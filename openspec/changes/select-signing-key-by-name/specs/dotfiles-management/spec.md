## ADDED Requirements

### Requirement: 署名鍵は利用側が与える名前で agent から選ぶ

システムは、git の署名に使う公開鍵を受け取る option を持ってはならず、生成する git の設定に公開鍵の文字列 (`user.signingkey`) を書いてはならない (MUST NOT)。鍵の実体は 1Password が管理し、利用側は鍵を指す名前 (1Password の項目名) だけを `dotfiles.git.signingKeyName` で与える。1Password の SSH agent は項目名を鍵のコメントとして返し、項目名を変えるとコメントも変わる。

git は署名のたびに agent の鍵の一覧を取り、コメントが名前と完全に一致する鍵がちょうど 1 本のときだけ、それを署名鍵にしなければならない (SHALL)。部分一致・前方一致で選んではならず、agent の鍵の本数や並び順に依存してはならない (MUST NOT)。別の鍵で署名してはならない (MUST NOT)。

次のいずれかでは、署名を中止し、名前とどの場合かが分かるメッセージを出さなければならない (SHALL)。(1) 一致する鍵が無い (agent に鍵が 1 本も無い場合を含む)。(2) 一致する鍵が 2 本以上ある。(3) agent に接続できない。メッセージは、どの agent (その Mac の 1Password か、転送された agent か) を見たかを示し、`user.signingkey` を設定して回避しないよう案内しなければならない (SHALL)。

署名の設定を出力する構成 (`dotfiles.onePassword.enable` が true で、`dotfiles.git.signingKeyName` が与えられている) で、利用側が git の設定の `user.signingkey` を宣言していれば、書き方 (キーの大文字小文字、home-manager の `programs.git.signing.key` を含む) によらず評価に失敗しなければならない (SHALL)。git は `user.signingkey` があると名前による選択を黙って使わなくなるためである。

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
- **THEN** 名前と、一致する鍵が複数あることと、見た agent を示すメッセージが出て、コミットは作られない
- **AND** どちらの鍵でも署名されない
- **AND** メッセージは `user.signingkey` を設定しないよう案内する

#### Scenario: agent に接続できない

- **WHEN** 手元で 1Password が起動しておらず、agent のソケットに接続できない状態で署名付きコミットを行う
- **THEN** 名前と、その Mac の 1Password の agent に接続できないことを示すメッセージが出て、コミットは作られない
- **AND** メッセージは `user.signingkey` を設定しないよう案内する

#### Scenario: user.signingkey との併用

- **WHEN** 利用側が `dotfiles.git.signingKeyName` を与え、`programs.git.settings.user.signingKey` (大文字小文字は問わない) または `programs.git.signing.key` も宣言して構成を評価する
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

## MODIFIED Requirements

### Requirement: 環境固有の値と私的な情報を書かない

このリポジトリは公開されている。システムは、環境固有の値 (ユーザー名、git の identity、署名鍵とそれを指す名前、ssh の接続先、特定の環境でだけ使うパッケージ) を持ってはならない (MUST NOT)。値は利用側が与える。

また、利用側の私的な情報 (ホスト名、ドメイン、アドレス、ネットワークやクラスタの構成) を、コード、コメント、コミットメッセージ、ブランチ名、PR と issue の文章、OpenSpec の成果物 (proposal / design / specs / tasks。archive したものを含む) のいずれにも書いてはならない (MUST NOT)。実測の記録は、役割の名前 (接続元の Mac、接続先の Mac、所有者の端末) で書かなければならない (SHALL)。

core のモジュールが利用側の宣言に頼る場合は、その前提を利用側が与えるものとして文書に書かなければならない (SHALL)。

#### Scenario: 実測の記録を書く

- **WHEN** 2 台の Mac の間で振る舞いを実測し、その結果をコメントや要件に書く
- **THEN** ホスト名ではなく、接続元・接続先のような役割の名前で書かれている

#### Scenario: 利用側の宣言に頼る設定

- **WHEN** core の設定が、利用側が導入するアプリやフォント、利用側の転送の宣言を前提にする
- **THEN** その前提が core の README の「利用側が与えるもの」に書かれている
