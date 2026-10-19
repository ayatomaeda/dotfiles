# Tasks

## 1. 手引きから 6 節を外す (1 コミット: `docs: 手引きから Claude Code の節を外す (drop-claude-code-from-consumer-guide)`)

- [x] 1.1 `docs/CONSUMER-GUIDE.md` の 6 節「Claude Code を宣言する場合の家の形」を見出しごと削り、7〜11 節を 6〜10 節に繰り上げる (design D1、D7)。`rg -n '^## ' docs/CONSUMER-GUIDE.md` が 1〜10 の連番で、`Claude Code を宣言する場合` が無いことで確かめる
- [x] 1.2 6 節を指していた参照と、6 節の外の `Claude Code` の言及を直す (design D3、D4、D5、D7)。編集の前に `rg -n 'Claude Code|6 節' docs/CONSUMER-GUIDE.md` で一覧を取り、次を 1 つずつ直す: 2 節の構造の木から guard・モジュール・ステータスラインのディレクトリの 3 行を外す、`flake.nix` の例から `anthropic-skills` の input を外す、2 節の `CLAUDE.md` の小節の「Claude Code の宣言の注意」を「エージェントの宣言の注意」に、5 節の cask の例の `"claude"` の注を外す、5 節の Homebrew の対象外の例の「Claude Code 本体」を「自動更新を持つエージェントの本体」に、7 節の「6 節の assertion」を「利用側が lock だけを上げた世代を評価で止める assertion を持つなら」の形に、herdr の skill の注を「パッケージの出力から build 時に生成するものを持つ利用側は、その入力が上がった lock の更新で build を通す (CI は評価だけ)」の形に、8 節の `(6 節の builtins.readFile)` を 6 節に頼らない文に、11 節の「Claude Code の `gh` の書き込みの検査」を「エージェントの `gh` の書き込みの検査」に書き直す。編集の後、一覧の各行が直っていて、`6 節` の当たりが無いことで確かめる (繰り上げは 1.3 で行う)
- [x] 1.3 繰り上げの前に、`rg -on '[0-9]+ 節' docs/CONSUMER-GUIDE.md` の各当たりについて「行番号: 参照 → 指し先の見出しの文字列」の表を作る (6 節の外に 6 か所。design D7)。見出しを繰り上げ、参照を直した後、同じコマンドで表を作り直し、各参照の指し先の見出しの文字列が前の表と一致することで確かめる (番号ではなく見出しの文字列で突き合わせる。古い番号の見出しも存在するので、番号だけの確認では見落としが通る)
- [x] 1.4 読み手を「人か、エージェント」に広げる (design D2): 1 節の読み手の記述、2 節の `CLAUDE.md` の小節と構造の木の `CLAUDE.md` の行を「エージェントに core の `CLAUDE.md` を読ませるなら」の形にし、7 節 (繰り上げ後 6 節) の「エージェントは build までを行う」と 9・10 節 (繰り上げ後 8・9 節) の「利用側のエージェント」を「人かエージェント」にする。合格の条件: `rg -n 'エージェント' docs/CONSUMER-GUIDE.md` の各行が、(a)「エージェントを使うなら」の条件付き、(b) 人と並記した役割の分担、(c) 家の事情の説明 (「家のエージェントは〜」) のどれかで、番号付きの手順の段階にエージェントを主語にしたものが無いこと
- [x] 1.5 初回の手順から「Claude Code を native インストーラで入れる」の段階を外し、番号を詰める (design D5)。そのうえで `rg -n 'Claude Code' docs/CONSUMER-GUIDE.md` が 0 件で、`rg -n -i 'claude' docs/CONSUMER-GUIDE.md` の当たりがすべて `CLAUDE.md` (ファイル名) であることで確かめる。当たりが残っていたら、削らずに役割の名前で書き直し、その箇所を 1.2 の一覧に足す (spec の「製品の名前が現れてよいのはファイル名だけ」の検査)
- [x] 1.6 手引きのリンクをすべて抽出し (`rg -o '\]\([^)]+\)' docs/CONSUMER-GUIDE.md`)、相対パスのファイルが在ること、`#` の付いたリンクの見出しが core の `README.md` / `CLAUDE.md` に在ることを突き合わせる (削った節へのリンクが残っていないこと)
- [x] 1.7 削る 6 節の各項が家の文書にあることを、項目ごとに突き合わせる (design D1 の根拠): 宣言のコード片 → 家の `modules/home/` の実物、`package = null` と native インストーラ → 家の `README.md` の「管理対象外にしているもの」、marketplaces・`claude mcp add`・`syncClaudeAiSkills` → 家の `CLAUDE.md` の「家の事情」、保存されない操作の表 → 家の `README.md` の「保存されない操作 (Claude Code)」、各 Mac の後片付け → 家の `README.md` の「Claude Code の拡張の後片付け」、資格情報を別ファイルから読む形 → 家の `CLAUDE.md` の context7 の項。家に無い項があれば、家に書き足す作業を家の側の PR に回し、この change には入れない。突き合わせの結果を design D1 の下に 1 行で記録し、冒頭の `最終照合:` を突き合わせた日に改める。`rg -n '^最終照合: [0-9]{4}-[0-9]{2}-[0-9]{2}$' docs/CONSUMER-GUIDE.md` が 1 件だけ当たることで確かめる

## 2. 公開の前の検査 (所有者の端末で)

- [x] 2.1 core のクローンで `<家の構成のクローン>/scripts/check-core.sh ../dotfiles` を実行し、終了コードが 0 であることを確かめる。当たったら語の一覧を変えず、手引きの文章を役割の名前に書き直して、再び 0 になるまで繰り返す
- [x] 2.2 コミットメッセージとブランチ名も同じ検査に通す (`git log --format=%B main..HEAD | <家の構成のクローン>/scripts/check-core.sh -`、`git branch --show-current | <家の構成のクローン>/scripts/check-core.sh --names`)。どちらも 0 であることを確かめる
- [x] 2.3 モジュールを変えていないことを確かめる: `git diff --stat main -- modules flake.nix ssh` が空であること (drvPath の照合は要らない)

## 3. archive と PR

- [x] 3.1 `openspec validate drop-claude-code-from-consumer-guide --strict` が通ることを確かめ、`openspec archive drop-claude-code-from-consumer-guide` で `openspec/specs/consumer-guide/spec.md` に delta を反映する。反映後の spec に `Claude Code` の語が残っていないことを `rg -n 'Claude Code' openspec/specs/consumer-guide/spec.md` で確かめ、2.1 の検査を再び通す (1 コミット: `docs: drop-claude-code-from-consumer-guide を archive して specs に反映する`)
- [ ] 3.2 PR の本文を書き、`<家の構成のクローン>/scripts/check-core.sh -` に本文を通して 0 であることを確かめてから PR を出す。本文に利用側の構成の名前を書かない
- [ ] 3.3 レビューを受けてマージする。家の側の作業 (lock の更新と、レビューの対象のパスの一覧の調整。design の Migration Plan 2) は家の PR で行う
