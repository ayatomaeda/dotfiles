## Context

今の署名の経路は次のとおり。

```
git commit
  user.signingkey = "key::<dotfiles.git.signingKey>"    ← 利用側が公開鍵の文字列を与える
  gpg.ssh.program = git-ssh-sign (ラッパー)
     ├─ ssh 越し / herdr のペイン → /usr/bin/ssh-keygen (転送された agent で署名)
     └─ それ以外                  → op-ssh-sign (その Mac の 1Password)
  gate: dotfiles.onePassword.enable && signingKey != null
```

鍵の実体は 1Password にあり、利用側のリポジトリにはその公開鍵の写しがある。これをやめ、利用側は
1Password の項目名だけを与えるようにする。

実測で分かっていること (接続元の Mac):

- 手元のシェルの `SSH_AUTH_SOCK` は launchd の agent を指し、鍵を持たない (`The agent has no identities`)。
  1Password の agent には ssh の `IdentityAgent` と `op-ssh-sign` からしか届かない。
- 1Password の agent に `ssh-add -L` を実行すると、承認なしで鍵の一覧が返る。鍵のコメントは、
  1Password の項目名と同じ文字列だった。
- `op` CLI は、アプリとの連携が無い構成ではセッションがサインインしたシェルの環境変数にしかなく、
  別のプロセスからは `could not find session token` になる。

## Goals / Non-Goals

**Goals:**

- 利用側のリポジトリに公開鍵を置かずに署名できる。利用側が与えるのは項目名だけにする。
- 手元、ssh 越し、herdr のペインのどれでも、今と同じ承認先 (`remote-access`) で署名できる。
- 名前に一致する鍵が無いときや、曖昧なときは署名せずに止める。
- 環境固有の値を core に持たない。

**Non-Goals:**

- 1Password を使わないホストでの署名。今と同じく `onePassword.enable` で gate する。
- sshd の authorized keys。利用側が宣言し、今のまま公開鍵を使う。
- 署名の検証 (`gpg.ssh.allowedSignersFile`)。今も設定していない。

## Decisions

### D1. 鍵は agent のコメントで選び、名前は 1Password の項目名にする

利用側が書く値として、次を比べた。

| 候補 | 鍵を作り直したとき | ssh 越し | 採否 |
|---|---|---|---|
| 1Password の項目名 (agent のコメント) | 同じ項目名なら利用側は変わらない | 転送された agent もコメントを返す | 採る |
| 鍵の fingerprint | 利用側も直す (鍵から計算した値の写し) | 照合できる | 採らない (二重管理が残る) |
| 項目 ID を `op` で引く (commit のたび) | 変わらない | 接続先の `op` が接続先の 1Password に問い合わせ、承認が無人の画面に出るか未サインインで失敗する | 採らない (`remote-access` に反する) |
| 項目名を `op` で引き、switch のときにファイルへ書き出す | 変わらない | ファイルがあるので動く | 採らない (switch が `op` のセッションに依存する。書き出したファイルが宣言の外の状態になる) |

### D2. 完全一致で、ちょうど 1 本のときだけ使う

`ssh-add -L` の各行の、鍵の種類と本体を除いた残り全体 (コメント) を名前と比べる。項目名は空白を
含みうるので、空白で区切った 3 列目だけを見ない。部分一致を使わない。

一致が 0 本なら「agent にその名前の鍵が無い」、2 本以上なら「名前が曖昧」として、名前を含む
メッセージを標準エラーに出して非 0 で終わる。git は署名を中止し、コミットは作られない。
最初の鍵を選ぶ形 (`ssh-add -L | head -1`) は、1Password に鍵が複数あると登録していない鍵で黙って署名し、
GitHub 上で Unverified になるだけで気づけないので採らない。

出力は `key::<種類> <本体>` とする。git は `key::` が付くか `ssh-` で始まる行だけを鍵として受け付けるため
(`ecdsa-sha2-…` は `key::` が無いと通らない)。コメントは出力しない。

### D3. agent の判定を 1 か所にまとめ、ラッパーと鍵を取るコマンドが共有する

鍵を取るコマンドも、ラッパーと同じ判定で agent を選ぶ必要がある。手元で `SSH_AUTH_SOCK` を見ると
launchd の空の agent に当たるためである。

```
isForwarded (git.nix の let に 1 つ)
  = [ -S "$SSH_AUTH_SOCK" ] && { [ -n "$SSH_CONNECTION" ] || [ "$SSH_AUTH_SOCK" = "$HOME/.ssh/agent-forward.sock" ]; }

signProgram  : isForwarded → ssh-keygen          / それ以外 → op-ssh-sign   (今のまま)
keyCommand   : isForwarded → "$SSH_AUTH_SOCK"    / それ以外 → 1Password の agent.sock
```

判定の文字列は Nix の let で 1 つにし、2 つのスクリプトへ埋め込む。ラッパーの中身は今と同じ文字列に
なるように書き、ラッパーの store パスが変わらないことを照合で確かめる。ssh.nix の `Match` は否定形で
引用の文脈も違うので、今と同じく別に書く。条件をそろえる場所は今と同じ 4 か所 (ssh.nix、git.nix、
`ssh/rc`、terminal.nix) で、増やさない。

### D4. 1Password の agent のソケットのパスは 1 か所に置き、internal の option で渡す

パスは今 ssh.nix の `IdentityAgent` にだけある。鍵を取るコマンドも必要とするので、2 か所目に
書かず、`dotfiles.internal.onePasswordAgentSocket` (`internal = true`、ホームディレクトリからの相対パス)
として 1 か所で定義する。ssh.nix は `"~/<相対パス>"`、鍵を取るコマンドは `"$HOME/<相対パス>"` として
使う。ssh の生成物の文字列は変えない。

モジュール間の受け渡しに internal の option を使うのは `multi-host-configuration` が認める形であり、
利用側が設定する option ではない。「パスそれ自体を option にしない」(`dotfiles-management`) は
利用側に見せる option を指す。代わりに Nix のファイルを `import` して共有する形もあるが、このリポジトリの
受け渡しの慣習 (internal の option) に合わせる。

### D5. `signingKey` は `mkRemovedOptionModule` で消す

意味が変わる (公開鍵 → 名前) ので `mkRenamedOptionModule` は使えない。残して併存させると、
二重管理を選べる余地が残る。消しておけば、古い行を持つ利用側は評価エラーで止まり、メッセージで
`signingKeyName` へ案内される。黙って署名されなくなることは無い。

### D6. gate は今のまま `onePassword.enable && signingKeyName != null`

鍵を取るコマンドは普通の ssh-agent でも動くが、1Password を使わないホストを持つ利用側が無く、
動作を確かめられない。広げるのは別の change とする。`/usr/bin/ssh-add` は macOS 固有のパスなので、
ラッパーの `/usr/bin/ssh-keygen` と同じく gate の内側でだけ使う。

## Risks / Trade-offs

- [コメントが項目名ではなく、取り込んだときの元のコメントかもしれない] → 1 台の実測では、項目名と
  コメントが同じ文字列で区別できなかった。1Password で項目名を一時的に変え、`ssh-add -L` の表示が
  変わるかを確かめる (tasks)。変わらなくても仕組みは成り立つので、そのときは「鍵のコメント」と説明し直す。
- [転送された agent がコメントを返さない] → agent の一覧の応答にはコメントが含まれるので返るはずだが、
  ssh 越しと herdr のペインで実測する (tasks)。
- [エラーの文言が利用者に届かない] → git が `defaultKeyCommand` の標準エラーを表示するかを確かめる。
  表示されないなら、メッセージの出し方を見直す。
- [署名のたびに `ssh-add -L` を実行する] → 一覧を取るだけで承認は出ない。所要時間を実測して記録する。
- [利用側が `programs.git.settings.user.signingkey` を直接書く] → git は `user.signingkey` があると
  `defaultKeyCommand` を使わない。README に「書かない」と明記する。
- [Claude Code のシェルなど古い環境のプロセス] → 判定は今のラッパーと同じなので、既知の制約
  (起動し直す) は変わらない。

## Migration Plan

1. core の変更を作り、利用側で手元のクローンを指して評価と build を確かめる
   (`--override-input core path:../dotfiles`。switch はしない)。
2. core をマージする。
3. 利用側で、`nix flake update core` と `signingKey` → `signingKeyName` の書き換えを**同じコミット**で行う。
   分けると、lock だけ上がった状態が評価エラーになる。
4. 所有者がそのコミットから switch し、手元・ssh 越し・herdr のペインで署名付きコミットを確かめる。

戻すときは、利用側のそのコミットを revert する (lock が前の core に戻り、`signingKey` の行も戻る)。

## Open Questions

- (なし。上の Risks の実測で確かめる)
