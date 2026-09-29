## Context

今の署名の経路:

```
git commit
  user.signingkey = "key::<dotfiles.git.signingKey>"    ← 利用側が公開鍵の文字列を与える
  gpg.ssh.program = git-ssh-sign (ラッパー)
     ├─ ssh 越し / herdr のペイン → /usr/bin/ssh-keygen (転送された agent で署名)
     └─ それ以外                  → op-ssh-sign (その Mac の 1Password)
  gate: dotfiles.onePassword.enable && signingKey != null
```

### 実測 (所有者の Mac、2026-09-29)

1Password の SSH agent のソケットに対する `ssh-add -L`:

| 確かめたこと | 結果 |
|---|---|
| コメントは項目名か | テスト用の SSH Key の項目を作り、アプリで名前を変えると、コメントがすぐに新しい名前になった。**コメントは項目名そのもの** |
| 鍵が複数のとき | 項目を足すと鍵が 2 本になり、**新しい鍵が一覧の先頭**に出た |
| 承認 | 一覧を取るだけでは承認は出ない |
| ロック中 | 承認なしで即座に返る (exit 0)。ただし**解除していた間に覚えた一覧**で、ロック中に足した鍵は解除するまで出ない |
| 手元の `SSH_AUTH_SOCK` | launchd の agent で、鍵を持たない (`The agent has no identities`) |
| Claude Code のシェルの `op` | 1Password のデータのディレクトリの設定ファイルの読み取りが `operation not permitted` になり、CLI 連携が効かない (パスワードでのサインインに落ちる)。同じディレクトリのソケットへの接続は通る |
| `op` での SSH Key の編集 | `SSH Key item editing in the CLI is not yet supported.` |

git 2.55.0 での実測 (使い捨ての鍵と一時的な agent):

- `user.signingkey` があると `defaultKeyCommand` は使われない。
- `defaultKeyCommand` の出力は 1 行目だけが使われ、`key::` が付くか `ssh-` で始まる行だけを受け付ける
  (`ecdsa-…` をそのまま返すと `succeeded but returned no keys`)。
- 非 0 で終わるとコミットは作られない。表示は次の 3 行 (最後の行は誤解を招く):
  `warning: gpg.ssh.defaultKeyCommand failed: <stderr> <stdout>` /
  `error: user.signingKey needs to be set for ssh signing` / `fatal: failed to write commit object`
- **シェルを通さずに実行される** (`false || echo …` は失敗し、`$HOME` は展開されない)。
- `ssh-keygen -Y sign -f <公開鍵>` は秘密鍵のファイルが無くても agent の鍵で署名できる (今のラッパーの経路が成り立つ)。
- `ssh-add -L` の終了コードは、鍵が無いとき 1 (標準出力に `The agent has no identities.`)、agent に接続できないとき 2。
  agent との通信に失敗したとき (`error fetching identities: …` を標準エラーに出す) も 1 になる (OpenSSH の実装)。

## Goals / Non-Goals

**Goals:**

- 利用側のリポジトリに署名のための公開鍵を置かない。利用側が与えるのは項目名だけ。
- 手元、ssh 越し、herdr のペインのどれでも、今と同じ承認先 (`remote-access`) で署名できる。
- agent に鍵が何本あっても、名前で 1 本を選ぶ。選べないときは署名せずに、理由の分かるメッセージで止める。
- core に環境固有の値を持たない。

**Non-Goals:**

- 1Password を使わないホストでの署名 (今と同じく `onePassword.enable` で gate する)。
- sshd の authorized keys (利用側が宣言する。この change では変えない)。
- 署名の検証 (`gpg.ssh.allowedSignersFile`)。今も設定していない。

## Decisions

### D1. 鍵は agent のコメントで選び、名前は 1Password の項目名にする

| 候補 | 鍵を作り直したとき | ssh 越し | 採否 |
|---|---|---|---|
| 1Password の項目名 (agent のコメント) | 同じ項目名なら利用側は変わらない | 転送された agent もコメントを返す | 採る |
| 鍵の fingerprint | 利用側も直す (鍵から計算した値の写し) | 照合できる | 採らない |
| 項目名から `op` で公開鍵を引く (commit のたび) | 変わらない | 接続先の `op` が接続先の 1Password に問い合わせ、承認が無人の画面に出るか未サインインで失敗する | 採らない |
| 項目名から `op` で公開鍵を引き、switch のときにファイルへ書き出す | 変わらない | ファイルがあるので動く | 採らない |

`op` を使う 2 案は、どちらも `op` のサインインの状態に依存する。さらに実測で、Claude Code のシェルからは CLI 連携が効かない
ことが分かった。commit のたびに `op` を呼ぶ形では、エージェントのコミットが必ず失敗する。

### D2. 名前との完全一致で、ちょうど 1 本のときだけ使う

`ssh-add -L` の各行の、鍵の種類と本体を除いた残り全体 (コメント) を名前と比べる。項目名は空白を含みうるので、空白で
区切った 3 列目だけを見ない。部分一致・前方一致・正規表現を使わない。agent の鍵は何本あってもよい。

| 状況 | 振る舞い |
|---|---|
| 一致がちょうど 1 本 | `key::<種類> <本体>` を 1 行出して 0 で終わる (コメントは出さない) |
| 一致が 0 本 (鍵はあるが名前が違う) | 「`<見た agent>` に `<名前>` という名前の鍵が無い」と出して非 0 |
| agent に鍵が 1 本も無い (終了コード 1 で、標準出力がちょうど `The agent has no identities.`) | 一致 0 本と同じ扱い。見た agent がその Mac の 1Password なら「ロックの解除と、SSH agent の設定を確かめる」、転送された agent なら「接続元で agent を転送しているか」を添える。案内文を鍵の行として解釈しない |
| 一致が 2 本以上 | 「`<見た agent>` に `<名前>` という名前の鍵が複数ある」と出して非 0。どちらでも署名しない |
| agent に接続できない (終了コード 2) | その Mac の 1Password なら「1Password が起動しているか」、転送された agent なら「転送の接続が切れていないか」を添えて非 0 |
| それ以外 (終了コード 1 で上に当たらないもの、その他の終了コード) | 終了コードと `ssh-add` の標準エラーを含む汎用のメッセージで非 0 |

- 「見た agent」は、D3 の判定の結果 (その Mac の 1Password か、転送された agent か) をそのまま使う。
- 失敗のメッセージには、どの場合も「`user.signingkey` を設定しないこと」を添える。git が最後に
  `user.signingKey needs to be set` と出すので、それを見て設定すると、この仕組みを黙って迂回してしまうため。
- 最初の鍵を使う形 (`ssh-add -L | head -1`) は採らない。実測では新しい鍵が先頭に出たので、1Password に鍵を 1 本足した
  だけで、登録していない鍵で黙って署名する (GitHub で Unverified になるだけで気づけない)。
- git はシェルを通さずに `defaultKeyCommand` を実行するので、名前は引数で渡さない。Nix の側で `lib.escapeShellArg` を
  かけてスクリプトの本文に埋め込み、`defaultKeyCommand` にはスクリプトの store パスだけを書く。`$HOME` の展開は
  スクリプトの中で行う。
- 名前の型は `nullOr nonEmptyStr` にする。空文字列はコメントの無い鍵に一致しかねない。
- 利用側が `user.signingkey` を宣言すると、git は `defaultKeyCommand` を使わなくなり、名前による選択が黙って外れる。
  宣言の書き方は `programs.git.settings.user.signingkey` のほかに、大文字小文字の違う `signingKey` (git のキーは大文字小文字を
  区別しない) や、home-manager の `programs.git.signing.key` (`iniContent.user.signingKey` に書き込む) がある。そこで
  assertion は `config.programs.git.iniContent.user` の属性名を小文字にして `signingkey` と比べる。
  assertion は署名の設定を出力するとき (`onePassword.enable && signingKeyName != null`) にだけ効かせる。署名の設定を
  出力しないホストでは、利用側が自分の `user.signingkey` を使ってもこの仕組みを迂回したことにならないため。
- 宣言の外 (`~/.gitconfig` の手書き、リポジトリの `.git/config`) の `user.signingkey` は検出できない。README に書く。

### D3. agent の判定を 1 つにまとめ、ラッパーと鍵を取るコマンドが共有する

手元で `SSH_AUTH_SOCK` を見ると launchd の空の agent に当たるので、鍵を取るコマンドもラッパーと同じ判定で agent を選ぶ。

```
isForwarded (git.nix の let に 1 つ)
  = [ -S "$SSH_AUTH_SOCK" ] && { [ -n "$SSH_CONNECTION" ] || [ "$SSH_AUTH_SOCK" = "$HOME/.ssh/agent-forward.sock" ]; }

signProgram : isForwarded → ssh-keygen       / それ以外 → op-ssh-sign   (今のまま)
keyCommand  : isForwarded → "$SSH_AUTH_SOCK" / それ以外 → 1Password の agent.sock
```

判定の文字列は Nix の let で 1 つにし、2 つのスクリプトへ埋め込む。ラッパーの中身は今と同じ文字列になるように書き、
store パスが変わらないことを照合で確かめる。ssh.nix の `Match` は否定形で引用の文脈も違うので、今と同じく別に書く。
判定の条件と固定パス (`~/.ssh/agent-forward.sock`) をそろえる場所は、今と同じ 4 か所 (ssh.nix の `Match`、git.nix の判定、
`ssh/rc`、terminal.nix) である。鍵を取るコマンドは git.nix の中の判定を使うので、そろえる場所は増えない。

### D4. 1Password 固有のパスは、値だけを持つ 1 つの .nix ファイルに置く

agent のソケットのパスは今 ssh.nix にだけあるが、鍵を取るコマンドも必要とする。`op-ssh-sign` のパスは git.nix にある。
これらを `modules/common/one-password.nix` (モジュールではなく、属性の集合を返すだけのファイル。`imports` に入れない) に
まとめ、ssh.nix と git.nix が `import` する。

```nix
{
  agentSocket = "Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";  # ホームからの相対パス
  signProgram = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
}
```

ssh.nix は `"~/${agentSocket}"`、鍵を取るコマンドは `"$HOME/${agentSocket}"` として使う。生成される ssh の設定と
ラッパーの文字列は変えない。

これは既存の要件 (`dotfiles-management` の「プラットフォーム固有の外部パスを無条件な事実として書かない」) を変えずに満たす。
その要件の「gate された 1 か所に閉じる」は、**値を定義するのは 1 か所で、それを使うのは gate の内側だけ**と読む。
`one-password.nix` は gate の外で読み込まれるが、値を定義するだけで何も出力しない。パスは option にならず、生成物に
現れるのは gate の内側で使った分だけである。`onePassword.enable = false` の構成の生成物に 1Password のパスと
`/usr/bin/ssh-add` が無いことを確かめる (tasks 4.4)。

internal の option で渡す案は採らない。`multi-host-configuration` の internal の例外は「モジュールが導出した値」の
受け渡しのためのもので、定数のパスは当たらない。`ssh -G` で `IdentityAgent` を読めば判定もパスも ssh.nix だけで済むが、
`CanonicalizeHostname` による名前の解決と `Match exec` の実行を毎回伴い、`ssh -G` の出力形式に依存するので採らない。

### D5. `signingKey` は `mkRemovedOptionModule` で消す

意味が変わる (公開鍵 → 名前) ので `mkRenamedOptionModule` は使えない。併存させると二重管理を選べる余地が残る。
古い行を持つ利用側は評価エラーで止まり、メッセージで `signingKeyName` へ案内される。黙って署名されなくなることは無い。

### D6. gate は `onePassword.enable && signingKeyName != null`

鍵を取るコマンドは普通の ssh-agent でも動くが、1Password を使わないホストを持つ利用側が無く、確かめられない。
`/usr/bin/ssh-add` は macOS 固有のパスなので、ラッパーの `/usr/bin/ssh-keygen` と同じく gate の内側でだけ使う。

## Risks / Trade-offs

- [ロック中の agent は古い一覧を返す] → 鍵の入れ替えや項目名の変更をロック中に行うと、解除するまで古い名前で選ばれる。
  README に「入れ替えの確認はロックを解除して行う」と書く。ふだんのロックとその解除では一覧は変わらない。
- [項目名を変えると署名が止まる] → 名前に一致する鍵が無くなり、コミットは名前を含むメッセージで止まる (黙って別の鍵に
  ならない)。項目名を変えるときは `signingKeyName` も直す (README に書く)。
- [同じ名前の項目を 2 つ作ると署名が止まる] → D2 のとおり止まる。鍵を入れ替えるときは、旧い項目の名前を先に変える
  (README に書く)。
- [git のエラーの最後の行が誤解を招く] → D2 のメッセージで `user.signingkey` を設定しないよう添え、README の
  「エラーの読み方」に 3 行をそのまま載せる。
- [転送された agent がコメントを返さない] → agent の一覧の応答はコメントを含み、転送はそれをそのまま中継するので返るはず。
  archive の前に tasks 4.7 で確かめる。
- [git の CLI 以外のクライアント (IDE の組み込み git など) は `defaultKeyCommand` に対応しないことがある] → README に書く。
- [Claude Code の sandbox を将来有効にする] → 鍵を取るコマンドは 1Password のソケットに直接つなぐ。今は通るが (実測)、
  sandbox の設定しだいで塞がれうる。そのときはエージェントのコミットだけが失敗する。
- [Claude Code のシェルなど、古い環境のプロセス] → 判定は今のラッパーと同じなので、既知の制約 (起動し直す) は変わらない。
- [署名のたびに `ssh-add -L` を実行する] → 一覧を取るだけで承認は出ない。所要時間を実測して記録する。
- [応答しない agent (スリープした接続元への転送など)] → `ssh-add -L` が返らず、署名が止まる。今のラッパーの署名と同じ
  制約で、sshd の `ClientAliveInterval` が転送を切るまで続く。
- [転送された agent がコメントを返すことを、archive の前に確かめる] → 利用側で switch する前に、build したスクリプトを
  接続先の Mac に置き、ssh 越しと herdr のペインで直接実行して確かめる (tasks 4.7)。

## Migration Plan

この change の PR には、まず成果物 (proposal / design / specs / tasks) を置いてレビューを受け、承認の後に実装を積む。
利用側での評価と build の確認を終えたら archive して (delta を `openspec/specs/` に反映)、マージする。

利用側の移行:

1. core の PR の段階で、利用側で `--override-input core path:../dotfiles` を付けて評価と build をし、変更前の生成物と比べる
   (switch しない)。
2. core のマージの後、利用側で `nix flake update core` と `signingKey` → `signingKeyName` の書き換えを**同じコミット**で行う。
   分けると、lock だけ上がった状態が評価エラーになる。lock を自動で更新する仕組みがある利用側では、その PR も同じ理由で
   CI の評価に落ちる (想定どおり)。
3. 利用側の lock が固定したコミットから switch し、手元・ssh 越し・herdr のペインで署名付きコミットを確かめる。

戻すときは、利用側の移行のコミットを revert して switch する。

## Open Questions

(なし)
