# remote-access Specification

## Purpose
Mac への SSH ログインを公開鍵認証に限ることと、所有者の端末同士の ssh で agent を転送し、git の操作と署名の承認を接続元で行えるようにすること。

## Requirements
### Requirement: SSH ログインは公開鍵認証に限る

システムは、macOS の sshd がパスワード認証およびキーボードインタラクティブ認証 (PAM 経由のパスワードを含む) を受け付けないように宣言しなければならない (SHALL)。

リモートログインは接続しているすべてのネットワークでポート 22 を開けるため、持ち歩く Mac では第三者から sshd に到達されうる。認証手段を公開鍵に限れば、到達されても試せる手段が無い。

#### Scenario: パスワードでのログイン試行

- **WHEN** 鍵を持たないクライアントが `ssh -o PubkeyAuthentication=no <host>` で接続を試みる
- **THEN** パスワードの入力を求められずに `Permission denied (publickey)` で拒否される

#### Scenario: 実効値の確認

- **WHEN** 構成を適用した後、あるいは macOS を更新した後に `sudo sshd -T` を実行する
- **THEN** `passwordauthentication no` / `kbdinteractiveauthentication no` / `authenticationmethods publickey` が出力される
- **AND** そうでない場合は、macOS 側の `sshd_config.d` の設定が先に読まれていないかを確認する

### Requirement: リモートログインの有効 / 無効は宣言しない

システムは、macOS のリモートログインのオン / オフを構成で固定してはならない (MUST NOT)。所有者はホストの使い方に応じて GUI で切り替える。

#### Scenario: GUI でオフにしたホストへの switch

- **WHEN** 所有者が GUI でリモートログインをオフにしたホストで switch する
- **THEN** sshd は起動されず、オフのまま残る

### Requirement: 所有者の Mac 同士の ssh では、承認を接続元で行える

システムは、所有者の Mac から別の所有者の Mac へ ssh して行う `git` の操作 (fetch / pull / push) とコミット署名について、agent 転送を使い、1Password の承認を**接続元の Mac** で求めなければならない (SHALL)。

以下、ssh する側の所有者の Mac を**接続元**、ssh される側の所有者の Mac を**接続先**と呼ぶ。転送を有効にする接続先は、利用側が宣言する (`programs.ssh.settings.<host>.ForwardAgent`)。

転送された agent を使うかどうかは、次のどちらかで判定しなければならない (SHALL)。(a) `SSH_CONNECTION` が設定され、かつ `SSH_AUTH_SOCK` のソケットが実在する (ssh 越しのシェル)。(b) `SSH_AUTH_SOCK` が転送用の固定パス (`~/.ssh/agent-forward.sock`) で、かつその先のソケットが実在する (herdr のペイン)。ssh の設定 (`modules/common/ssh.nix` の 1Password の `Match`) と署名ラッパーは同じ条件を使わなければならない (SHALL)。tmux は detach のときに環境を戻さないので、`SSH_CONNECTION` だけでは切断後の古い値を拾う。`SSH_TTY` は TTY を伴わない実行で設定されないため、判定に使ってはならない (MUST NOT)。

ssh 越しでないときは、従来どおりその Mac 自身の 1Password を使わなければならない (SHALL)。

転送付きの ssh ログインのとき、固定パスの先のソケットが実在しなければ、その接続の転送ソケットへの symlink に張り替えなければならない (SHALL)。先が実在する間は張り替えてはならない (MUST NOT)。短い接続がリンクを奪い、その接続の終了とともに先が消えるためである。sshd は応答しないクライアントの接続を切り、転送ソケットを消さなければならない (SHALL)。張り替えの処理は、ssh の接続に何も出力してはならない (MUST NOT)。

#### Scenario: 対話 ssh での pull と署名

- **WHEN** 接続元から `ssh <接続先>` し、`git pull` と署名付きコミットを行う
- **THEN** 1Password の承認は接続元に表示され、承認すると両方が成功する

#### Scenario: TTY を伴わない実行

- **WHEN** 接続元から `ssh <接続先> 'git -C <repo> fetch'` を実行する
- **THEN** 承認は接続元に表示され、コマンドが成功する

#### Scenario: tmux に attach し直した後の対話シェル

- **WHEN** 接続先の前で起動した tmux に、接続元から ssh して attach する
- **AND** 既存のペインの対話シェルで `git pull` を行う
- **THEN** 承認は接続元に表示され、`git pull` が成功する

#### Scenario: ssh で attach して切断した後のローカル操作

- **WHEN** 接続先の前のクライアントを tmux に attach したまま、接続元から ssh して同じセッションに attach し、detach して切断する
- **AND** 接続先の前で、既存のペインと新しいペインで `git pull` と署名付きコミットを行う
- **THEN** 接続先自身の 1Password が承認を求め、両方が成功する

#### Scenario: ローカル操作

- **WHEN** 接続先の前で (tmux の中を含む) `git pull` と署名付きコミットを行う
- **AND** そのセッションに最後に attach したのが接続先の前である
- **AND** herdr のペインで行う場合は、接続元から接続先への転送付きの ssh 接続が残っていない
- **THEN** 接続先自身の 1Password が承認を求める

#### Scenario: herdr のペインでの再接続

- **WHEN** 接続元から接続先の herdr に接続し、切断して、もう一度接続する
- **AND** 接続前から動いている herdr のペインで `git push` と署名付きコミットを行う
- **THEN** 承認は接続元に表示され、両方が成功する

#### Scenario: 接続が残ったままの接続先での herdr の操作

- **WHEN** 接続元から接続先への転送付きの ssh 接続が残っている
- **AND** 接続先の前で herdr のペインから署名付きコミットを行う
- **THEN** 承認は接続元に表示される (既知の制約。接続先の前で使う前に接続元の herdr を終了して避ける)

#### Scenario: 張り替えが ssh の通信を壊さない

- **WHEN** 接続元から `ssh <接続先> 'git -C <repo> fetch'`、`scp`、herdr の接続を行う
- **THEN** いずれも `~/.ssh/rc` の出力に妨げられずに成功する

#### Scenario: herdr で接続中の短い ssh 接続

- **WHEN** 接続元から接続先の herdr に接続している
- **AND** 接続元から `ssh <接続先> 'git -C <repo> fetch'` を実行し、終わってから 30 秒待つ
- **THEN** herdr のペインでの署名の承認は接続元に表示される

#### Scenario: 接続元がスリープした後の接続先での操作

- **WHEN** 接続元から接続先の herdr に接続したまま接続元をスリープさせ、2 分待つ
- **AND** 接続先の前で herdr のペインから署名付きコミットを行う
- **THEN** 接続先自身の 1Password が承認を求める

