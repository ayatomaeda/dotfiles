## 1. 基準の記録

- [x] 1.1 このリポジトリの main を指して、利用側で `--override-input core path:../dotfiles` を付け、各ホストの drvPath と、生成された git の設定・ssh の設定・署名のラッパーの store パスを記録する

## 2. option と 1Password のパス

- [x] 2.1 `modules/common/one-password.nix` (値だけのファイル。`imports` に入れない) に agent のソケット (ホームからの相対パス) と `op-ssh-sign` のパスを置き、ssh.nix と git.nix がそれを import する形に変える (生成される ssh の設定とラッパーの文字列は変えない)
- [x] 2.2 `modules/common/options.nix` に `dotfiles.git.signingKeyName` (`nullOr nonEmptyStr`、既定 `null`) を足す。説明に「1Password の項目名 (agent が返す鍵のコメント)」「null なら署名しない」「項目名を変えたらこの値も直す」「`user.signingkey` を直接書かない」を書く
- [x] 2.3 `dotfiles.git.signingKey` を `lib.mkRemovedOptionModule` で消し、`signingKeyName` へ移す案内をメッセージに入れる
- [x] 2.4 options.nix 冒頭のコメントの「現在の option」を更新する

## 3. 署名

- [x] 3.1 git.nix で、転送された agent を使うかの判定を let の 1 つにまとめ、署名のラッパーに埋め込む (ラッパーの中身は変えない)
- [x] 3.2 鍵を選ぶスクリプトを足す (design D2): 判定で agent を選び、`/usr/bin/ssh-add -L` の終了コードと出力から、コメントが名前と完全に一致する行を選んで `key::<種類> <本体>` を出す。名前は `lib.escapeShellArg` でスクリプトに埋め込み、`$HOME` はスクリプトの中で展開する。一致なし (終了コード 1 で標準出力がちょうど `The agent has no identities.` のときの鍵 0 本を含む)・重複・接続できない (終了コード 2)・その他 (それ以外の終了コード 1 を含む。終了コードと標準エラーを示す) を別のメッセージにし、見た agent を示し、`user.signingkey` を設定しないよう案内する
- [x] 3.3 署名の設定の gate を `onePassword.enable && signingKeyName != null` に変え、`user.signingkey` の代わりに `gpg.ssh.defaultKeyCommand` (スクリプトの store パスだけ) を出力する
- [x] 3.4 署名の設定を出力するとき (`onePassword.enable && signingKeyName != null`) に、`config.programs.git.iniContent.user` の属性名を小文字にして `signingkey` があれば評価を止める assertion を足す (`user.signingkey` を消すよう案内する)
- [x] 3.5 コメントを更新する (判定の条件と固定パスをそろえる 4 か所、`op` を使わない理由、項目名との対応)
- [x] 3.6 `flake.nix` の評価用の例の構成に架空の `dotfiles.git.signingKeyName` を与え、署名の分岐を CI で評価させる

## 4. 確認 (利用側で、手元のクローンを指して。switch はしない)

- [x] 4.1 利用側の `signingKey` の行を `signingKeyName` に書き換え (コミットしない)、`--override-input core path:../dotfiles` で各ホストを評価と build する
- [x] 4.2 生成物を 1.1 と比べる: git の設定は `user.signingkey` が消えて `gpg.ssh.defaultKeyCommand` が増えるだけ。ssh の設定とラッパーの store パスは変わらない
- [x] 4.3 評価が失敗することを確かめる: `signingKey` を残したとき (移行の案内)、`user.signingkey` を併用したとき (消す案内。`settings.user.signingkey`・`settings.user.signingKey`・`programs.git.signing.key` の 3 通り)、`onePassword.enable = false` で `user.signingkey` を宣言したとき (止まらないこと)、`signingKeyName = ""` のとき
- [x] 4.4 `signingKeyName` を与えない構成と `onePassword.enable = false` の構成で、`commit.gpgsign`・`gpg.format`・`gpg.ssh.program`・`gpg.ssh.defaultKeyCommand` がどれも出力されず、生成物 (home-files と git の設定) に 1Password のパスと `/usr/bin/ssh-add` が無いことを確かめる。このリポジトリの例の構成も評価する
- [x] 4.5 build した鍵を選ぶスクリプトを、使い捨ての鍵と一時的な agent で試す: 一致 1 本 / 一致が先頭でない / 一致 0 本 / 鍵が 0 本の agent / 一致 2 本 / agent に接続できない / 通信に失敗する agent (終了コード 1 で案内文が無い) / 実物の 1Password の agent (ロック中を含む) / Claude Code のシェルからの実行 / 空白を含む名前 / 名前を先頭に含む別の鍵だけ / 正規表現の記号を含む名前 / コメントの無い鍵 / ecdsa の鍵。出力・終了コード・メッセージ (見た agent を含む) と、1 回の所要時間を記録する
- [x] 4.6 使い捨てのリポジトリで、名前に一致しない場合の git の表示 (3 行) を確かめ、README に載せる文面と合わせる
- [x] 4.7 build したスクリプトを接続先の Mac に置き (`nix copy` など。switch しない)、接続元からの `ssh <接続先> '<スクリプトの store パス>'` と、接続先の herdr のペイン (接続元から接続したもの) で直接実行し、転送された agent の鍵が名前で選ばれることと、見た agent の表示を確かめる

## 5. 文書

- [x] 5.1 `README.md`: option の表、利用例 (`signingKeyName = "<項目名>"`)、authorized keys の例に「署名とは独立」の注記、項目名の決め方と変えたときの注意 (ロックを解除して確かめる、同じ名前を 2 つ作らない)、エラーの読み方 (git の 3 行とスクリプトのメッセージ)、`user.signingkey` を書かないこと (宣言の外の `~/.gitconfig` や `.git/config` を含む)、IDE の組み込み git の注意、「利用側が与えるもの」の表に項目名の前提 (署名する Mac と ssh の接続元のどれの 1Password にも、その名前の鍵がちょうど 1 本あり、SSH agent が出していること)、移行 (lock の更新と書き換えを同じコミットで)
- [x] 5.2 `docs/GUIDE.md` の署名の説明を更新する
- [x] 5.3 `CLAUDE.md`: 現在の option の一覧、判定の条件と固定パスを持つ場所と鍵を選ぶコマンドの関係、1Password 固有のパスの置き場所
- [x] 5.4 `CLAUDE.md` 冒頭の「経緯はこのリポジトリには無く、現在の要件だけが `openspec/specs/` にある」を改め、以後の変更は OpenSpec の change としてこのリポジトリに置き、成果物にも利用側の私的な情報を書かないことを書く。既存のコメントにある change の名前 (`remote-agent-forwarding` など) は、引き続き所有者の非公開の設計記録を指すことは残す

## 6. archive とマージ

- [x] 6.1 利用側の禁止語の検査を通す
- [x] 6.2 `openspec archive select-signing-key-by-name` で delta を `openspec/specs/` に反映し、この PR に積む
- [ ] 6.3 この PR のレビューを受けてマージする
