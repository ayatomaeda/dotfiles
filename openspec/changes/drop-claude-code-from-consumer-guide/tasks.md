# Tasks

## 1. 手引きから 6 節を外す (1 コミット: `docs: 手引きから Claude Code の節を外す (drop-claude-code-from-consumer-guide)`)

- [ ] 1.1 `docs/CONSUMER-GUIDE.md` の 6 節「Claude Code を宣言する場合の家の形」を見出しごと削り、7〜11 節を 6〜10 節に繰り上げる (design D1、D7)。`rg -n '^## ' docs/CONSUMER-GUIDE.md` が 1〜10 の連番で、`Claude Code を宣言する場合` が無いことで確かめる
- [ ] 1.2 6 節を指していた参照を直す (design D3、D4、D5、D7): 2 節の構造の木から Claude Code の guard・モジュール・ステータスラインのディレクトリの行を外す、`flake.nix` の例から `anthropic-skills` の input を外す、cask の例の `"claude"` の注を外す、7 節の「6 節の assertion」を「利用側が lock だけを上げた世代を評価で止める assertion を持つなら」の形に、herdr の注を生成物の名前を出さない形に、8 節の `(6 節の builtins.readFile)` を 6 節に頼らない文に書き直す。`rg -n '6 節' docs/CONSUMER-GUIDE.md` の当たりがすべて繰り上げ後の 6 節 (日々の運用) を指していることで確かめる
- [ ] 1.3 節番号のほかの相互参照 (`7 節`〜`11 節`) を繰り上げ後の番号に直す。`rg -n '[0-9]+ 節' docs/CONSUMER-GUIDE.md` の当たりを 1 つずつ、指している見出しと突き合わせる
- [ ] 1.4 読み手を「人か、エージェント」に広げる (design D2): 1 節の読み手の記述、2 節の `CLAUDE.md` の小節と構造の木の `CLAUDE.md` の行を「エージェントに core の `CLAUDE.md` を読ませるなら」の形にし、7 節 (繰り上げ後 6 節) の「エージェントは build までを行う」と 9・10 節 (繰り上げ後 8・9 節) の「利用側のエージェント」を「人かエージェント」にする。`rg -n 'エージェント' docs/CONSUMER-GUIDE.md` の各行が、エージェントを使わない利用側で矛盾しない文であることを読み返して確かめる
- [ ] 1.5 初回の手順から「Claude Code を native インストーラで入れる」の段階を外し、番号を詰める (design D5)。`rg -n -i 'claude' docs/CONSUMER-GUIDE.md` の当たりが、`CLAUDE.md` へのリンクと、10 節の「家にあって書かないもの」の検査の名前だけであることで確かめる
- [ ] 1.6 手引きのリンクをすべて抽出し (`rg -o '\]\([^)]+\)' docs/CONSUMER-GUIDE.md`)、相対パスのファイルが在ること、`#` の付いたリンクの見出しが core の `README.md` / `CLAUDE.md` に在ることを突き合わせる (削った節へのリンクが残っていないこと)
- [ ] 1.7 冒頭の `最終照合:` を、家の構成 (家の `README.md`・`CLAUDE.md` に 6 節の各項があること) と突き合わせた日に改める。`rg -n '^最終照合: [0-9]{4}-[0-9]{2}-[0-9]{2}$' docs/CONSUMER-GUIDE.md` が 1 件だけ当たることで確かめる

## 2. 公開の前の検査 (所有者の端末で)

- [ ] 2.1 core のクローンで `<家の構成のクローン>/scripts/check-core.sh ../dotfiles` を実行し、終了コードが 0 であることを確かめる。当たったら語の一覧を変えず、手引きの文章を役割の名前に書き直して、再び 0 になるまで繰り返す
- [ ] 2.2 コミットメッセージとブランチ名も同じ検査に通す (`git log --format=%B main..HEAD | <家の構成のクローン>/scripts/check-core.sh -`、`git branch --show-current | <家の構成のクローン>/scripts/check-core.sh --names`)。どちらも 0 であることを確かめる
- [ ] 2.3 モジュールを変えていないことを確かめる: `git diff --stat main -- modules flake.nix ssh` が空であること (drvPath の照合は要らない)

## 3. archive と PR

- [ ] 3.1 `openspec validate drop-claude-code-from-consumer-guide --strict` が通ることを確かめ、`openspec archive drop-claude-code-from-consumer-guide` で `openspec/specs/consumer-guide/spec.md` に delta を反映する。反映後の spec に `Claude Code` の語が残っていないことを `rg -n 'Claude Code' openspec/specs/consumer-guide/spec.md` で確かめ、2.1 の検査を再び通す (1 コミット: `docs: drop-claude-code-from-consumer-guide を archive して specs に反映する`)
- [ ] 3.2 PR の本文を書き、`<家の構成のクローン>/scripts/check-core.sh -` に本文を通して 0 であることを確かめてから PR を出す。本文に利用側の構成の名前を書かない
- [ ] 3.3 レビューを受けてマージする。家の側の作業 (lock の更新と、レビューの対象のパスの一覧の調整。design の Migration Plan 2) は家の PR で行う
