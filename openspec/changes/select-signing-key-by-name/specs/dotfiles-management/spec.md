## ADDED Requirements

### Requirement: 署名鍵は利用側が与える名前で agent から選ぶ

システムは、git の署名に使う公開鍵を、利用側の構成に文字列として持たせてはならない (MUST NOT)。鍵の実体は 1Password が管理し、利用側は鍵を指す名前 (1Password の項目名。agent が返す鍵のコメント) だけを `dotfiles.git.signingKeyName` で与えなければならない (SHALL)。

git は署名のたびに agent の鍵の一覧を取り、コメントが名前と完全に一致する鍵がちょうど 1 本のときだけ、それを署名鍵にしなければならない (SHALL)。一致が 0 本または 2 本以上のときは、名前を含むメッセージを出して署名を中止しなければならない (SHALL)。別の鍵で署名してはならない (MUST NOT)。

鍵を選ぶために、実行時に `op` CLI を使ってはならない (MUST NOT)。`op` はサインインの状態に依存し、ssh 越しでは接続先の 1Password に問い合わせるためである。

名前が与えられないとき (`null`)、または `dotfiles.onePassword.enable` が false のときは、署名の設定を出力してはならない (MUST NOT)。公開鍵を与える旧来の option (`dotfiles.git.signingKey`) は存在してはならず、与えた構成は、移行先を示すメッセージとともに評価に失敗しなければならない (SHALL)。

#### Scenario: 名前に一致する鍵が 1 本

- **WHEN** 利用側が `dotfiles.git.signingKeyName` に 1Password の項目名を与え、手元で署名付きコミットを行う
- **THEN** その項目の鍵で署名され、1Password の承認はその Mac に出る
- **AND** 生成された git の設定に公開鍵の文字列 (`user.signingkey`) が含まれない

#### Scenario: 名前に一致する鍵が無い

- **WHEN** agent に、コメントが名前と一致する鍵が無い状態で署名付きコミットを行う
- **THEN** 名前を含むメッセージが出て、コミットは作られない

#### Scenario: 名前が曖昧

- **WHEN** agent に、コメントが名前と一致する鍵が 2 本以上ある状態で署名付きコミットを行う
- **THEN** 名前を含むメッセージが出て、コミットは作られない
- **AND** どちらの鍵でも署名されない

#### Scenario: 名前を与えない利用側

- **WHEN** 利用側が `dotfiles.git.signingKeyName` を与えない
- **THEN** 生成された git の設定に `commit.gpgsign` も `gpg.ssh.defaultKeyCommand` も入らない
- **AND** コミットは署名されずに成功する

#### Scenario: 旧来の option を与えた利用側

- **WHEN** 利用側が `dotfiles.git.signingKey` を与えて構成を評価する
- **THEN** 評価は失敗し、`dotfiles.git.signingKeyName` へ移すよう案内するメッセージが出る
