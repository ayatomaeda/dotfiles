## Why

git の署名に使う鍵は 1Password で一元管理しているのに、`dotfiles.git.signingKey` は**公開鍵の文字列そのもの**を
求めるので、利用側のリポジトリに同じ公開鍵の写しを置くことになる。二重管理であり、鍵を作り直すと利用側も直す必要がある。

利用側が書くのは「どの鍵を使うか」を指す名前 (1Password の項目名) だけにし、公開鍵は 1Password の SSH agent から取る。
core を使う利用側はどれも 1Password を使う前提なので、公開鍵を渡す手段は残さない。

## What Changes

- **BREAKING:** `dotfiles.git.signingKey` を廃止する。与えた構成は、`dotfiles.git.signingKeyName` へ移すよう案内する
  メッセージとともに評価に失敗する (`lib.mkRemovedOptionModule`)。
- `dotfiles.git.signingKeyName` を足す。1Password の項目名を利用側が与える。既定値は `null` で、`null` なら今と同じく
  署名の設定を出力しない。空文字列は受け付けない。
- git は署名のたびに `gpg.ssh.defaultKeyCommand` で agent の鍵の一覧を取り、コメント (1Password の agent では項目名) が
  名前と**完全に一致する鍵がちょうど 1 本**のときだけ、それを署名鍵にする。agent の鍵は何本あってもよい。一致する鍵が無い、
  同じ名前の鍵が複数ある、agent に接続できない、のいずれかでは、理由と名前と見た agent を示すメッセージで止める。
- 鍵の一覧を取る agent は、署名のラッパーと**同じ判定**で選ぶ (手元は 1Password、ssh 越しと herdr のペインは転送された agent)。
- `signingKeyName` と、利用側が直接書いた `user.signingkey` が同時にある構成は評価で止める。
- 実行時に `op` CLI を使わない。
- 1Password 固有のパス (agent のソケット、`op-ssh-sign`) を、値だけを持つ 1 つの .nix ファイルにまとめ、ssh.nix と git.nix が
  読み込む。option にはしない。
- 評価用の例の構成に架空の `signingKeyName` を与え、署名の分岐を CI で評価する。
- CLAUDE.md の「経緯はこのリポジトリには無く」を改める。以後の変更は OpenSpec の change としてこのリポジトリに置く。

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `dotfiles-management`: 署名鍵を利用側の名前で agent から選ぶ要件を足す。「環境固有の値と私的な情報を書かない」の列挙に「鍵を指す名前」を含め、私的な情報を書いてはならない場所に OpenSpec の成果物を加える (change をこのリポジトリに置くようにするため)。
- `remote-access`: 転送された agent を使うかの判定を、署名鍵を選ぶコマンドにも適用する。
- `multi-host-configuration`: 環境固有の値の列挙と「モジュールが読む値」の例を、署名鍵の名前に改める。

## Impact

- **コード:** `modules/common/options.nix`、`modules/common/git.nix`、`modules/common/ssh.nix`、
  新しい `modules/common/one-password.nix` (値だけのファイル)、`flake.nix` (評価用の例の構成)。
- **文書:** `README.md` (option の表、利用例、エラーの読み方、移行)、`docs/GUIDE.md`、`CLAUDE.md`。
- **利用側:** `dotfiles.git.signingKey = …` の行を `dotfiles.git.signingKeyName = "<項目名>";` に置き換える。
  lock の更新と同じコミットで行う (分けると評価エラーになる)。
- **生成物:** 利用側の drvPath は変わる。git の設定で `user.signingkey` が消えて `gpg.ssh.defaultKeyCommand` が増えるだけで
  あること、ssh の設定と署名のラッパーが変わらないことを確かめる。
- **実行時:** 署名のたびに `ssh-add -L` を 1 回実行する。一覧を取るだけで、1Password の承認は出ない (ロック中も出ない)。
