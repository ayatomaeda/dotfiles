## Why

git の署名に使う鍵は、秘密鍵も公開鍵も 1Password で一元管理している。ところが core の
`dotfiles.git.signingKey` は**公開鍵の文字列そのもの**を求めるので、利用側のリポジトリに 1Password と
同じ公開鍵の写しを置くことになる。二重管理であり、鍵を作り直すと利用側のリポジトリも直す必要がある。

利用側が書くのは「どの鍵を使うか」を指す名前 (1Password の項目名) だけにし、公開鍵そのものは
1Password の SSH agent から取る形に改める。core を使う利用側はどれも 1Password を使う前提なので、
公開鍵を渡す手段は残さない。

## What Changes

- **BREAKING:** `dotfiles.git.signingKey` を廃止する。与えている利用側は評価エラーになり、
  `dotfiles.git.signingKeyName` へ移すよう案内される (`lib.mkRemovedOptionModule`)。
- `dotfiles.git.signingKeyName` を足す。1Password の項目名 (agent が返す鍵のコメント) を利用側が与える。
  既定値は `null` で、`null` なら今と同じく署名の設定を出力しない。
- git は署名のたびに `gpg.ssh.defaultKeyCommand` で agent の鍵の一覧を取り、コメントが名前と
  **完全に一致する鍵がちょうど 1 本**のときだけ、それを署名鍵にする。0 本や 2 本以上なら、名前を含む
  エラーで止める (別の鍵で黙って署名しない)。
- 鍵の一覧を取る agent は、署名のラッパーと**同じ判定**で選ぶ。手元では 1Password の agent、ssh 越しと
  herdr のペインでは転送された agent を使う。判定は 1 か所にまとめ、ラッパーと鍵を取るコマンドの両方が使う。
- 実行時に `op` CLI を使わない。サインインの状態や、ssh 越しに接続先の 1Password に問い合わせることに
  左右されないようにするため。
- 署名するのは、今と同じく `dotfiles.onePassword.enable` が true のときだけとする。

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `multi-host-configuration`: 「モジュールが読む値」の例を、署名鍵から署名鍵の名前に改める。
- `remote-access`: 転送された agent を使うかの判定を、署名のラッパーに加えて署名鍵を選ぶコマンドにも
  適用する。
- `dotfiles-management`: git の署名の要件に、利用側の名前で agent から鍵を選ぶことと、一致しないときは
  署名しないことを足す。1Password のソケットのパスを 1 か所に閉じる要件は変えない。

## Impact

- **コード:** `modules/common/options.nix` (option の廃止と追加)、`modules/common/git.nix`
  (鍵を選ぶコマンド、判定の共通化)、`modules/common/ssh.nix` (1Password のソケットのパスの共有)。
- **利用側:** `dotfiles.git.signingKey = …` の行を `dotfiles.git.signingKeyName = "<項目名>";` に
  置き換える。lock の更新と同じコミットで行う (分けると評価エラーになる)。
- **生成物:** 利用側の drvPath は変わる。生成された git の設定で、`user.signingkey` が消えて
  `gpg.ssh.defaultKeyCommand` が増えるだけであることを確かめる。ssh の設定は変わらない。
- **文書:** `README.md` (option の表、項目名の決め方、エラーの読み方)、`docs/GUIDE.md`、`CLAUDE.md`。
- **実行時:** 署名のたびに `ssh-add -L` を 1 回実行する。一覧を取るだけなので、1Password の承認は出ない。
