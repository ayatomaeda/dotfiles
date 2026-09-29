## 1. 事前の実測

- [ ] 1.1 1Password で項目名を一時的に変え、`ssh-add -L` (1Password の agent) のコメントが追従するかを確かめる。追従しなければ、文書と spec の「項目名」を「鍵のコメント」と説明し直す
- [ ] 1.2 git が `gpg.ssh.defaultKeyCommand` の標準エラーを利用者に表示するかを、使い捨てのリポジトリと失敗するコマンドで確かめる
- [ ] 1.3 変更前の基準として、利用側の各ホストの `toplevel` の drvPath と、生成された `~/.config/git/config`・`~/.ssh/config`・署名のラッパーの store パスを記録する

## 2. option

- [ ] 2.1 `modules/common/options.nix` に `dotfiles.git.signingKeyName` (`nullOr str`、既定 `null`) を足し、説明に「1Password の項目名 (agent が返す鍵のコメント)」「null なら署名しない」「`user.signingkey` を直接書かない」を書く
- [ ] 2.2 `dotfiles.git.signingKey` を `lib.mkRemovedOptionModule` で消し、`signingKeyName` へ移す案内をメッセージに入れる
- [ ] 2.3 `dotfiles.internal.onePasswordAgentSocket` (`internal = true`、ホームからの相対パス) を足す。冒頭のコメントの「現在の option」を更新する

## 3. 署名

- [ ] 3.1 `modules/common/ssh.nix` の `IdentityAgent` を、internal の option から組み立てる形に変える (生成される行は変えない)
- [ ] 3.2 `modules/common/git.nix` で、転送された agent を使うかの判定を let の 1 つにまとめ、署名のラッパーに埋め込む (ラッパーの中身は変えない)
- [ ] 3.3 鍵を選ぶスクリプトを足す: 判定で agent を選び、`/usr/bin/ssh-add -L` からコメントが名前と完全に一致する行を 1 本だけ選んで `key::<種類> <本体>` を出す。0 本・2 本以上は名前を含むメッセージを標準エラーに出して非 0 で終わる
- [ ] 3.4 署名の設定の gate を `onePassword.enable && signingKeyName != null` に変え、`user.signingkey` の代わりに `gpg.ssh.defaultKeyCommand` を出力する
- [ ] 3.5 コメント (判定をそろえる 4 か所の説明、`op` を使わない理由) を更新する

## 4. 振る舞いの確認 (利用側で、手元のクローンを指して。switch はしない)

- [ ] 4.1 利用側の `signingKey` の行を `signingKeyName` に置き換え、`--override-input core path:../dotfiles` で各ホストを評価と build する
- [ ] 4.2 生成物を 1.3 と比べる: git の設定は `user.signingkey` が消えて `gpg.ssh.defaultKeyCommand` が増えるだけ、ssh の設定とラッパーの store パスは変わらない
- [ ] 4.3 `signingKey` を残したまま評価し、移行を案内するメッセージで失敗することを確かめる
- [ ] 4.4 `signingKeyName` を与えない構成と `onePassword.enable = false` の構成で、署名の設定が出力されないことを確かめる (評価用の例の構成と CI を含む)
- [ ] 4.5 build した鍵を選ぶスクリプトを直接実行し、一致 1 本・一致なし・一致 2 本 (偽の agent で再現する) の 3 通りの出力と終了コードを確かめる。1 回の所要時間を記録する

## 5. 文書

- [ ] 5.1 `README.md`: option の表、利用側の例 (`signingKeyName = "<項目名>"`)、項目名の決め方、エラーの読み方、移行の手順 (lock の更新と書き換えを同じコミットで)
- [ ] 5.2 `docs/GUIDE.md`: 署名の説明を更新する
- [ ] 5.3 `CLAUDE.md`: 現在の option の一覧を更新し、判定をそろえる場所の説明に鍵を選ぶコマンドを足す
- [ ] 5.4 利用側の禁止語の検査 (`check-core.sh`) を通す

## 6. 反映と実機の確認 (マージの後、所有者が行う)

- [ ] 6.1 利用側で `nix flake update core` と `signingKeyName` への書き換えを同じコミットにし、そのコミットから switch する
- [ ] 6.2 手元で署名付きコミットを行い、承認がその Mac に出て、GitHub で Verified になることを確かめる
- [ ] 6.3 接続元から ssh 越しに署名付きコミットを行い、承認が接続元に出ることを確かめる (TTY なしの `ssh <接続先> 'git …'` を含む)
- [ ] 6.4 herdr のペインで、接続し直した後に署名付きコミットを行い、承認が接続元に出ることを確かめる
- [ ] 6.5 spec の delta を `openspec/specs/` に反映して archive する
