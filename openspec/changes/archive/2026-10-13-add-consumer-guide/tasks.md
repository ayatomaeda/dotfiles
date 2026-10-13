## 1. 手引きを書く (1 コミット: `docs: 利用側の作り方と運用の手引きを足す (add-consumer-guide)`)

- [x] 1.1 `docs/CONSUMER-GUIDE.md` を作り、表題の直後に `最終照合: YYYY-MM-DD` (照合した日) の 1 行と、読み方の段落 (design D2、D7) を置く。`rg -n '^最終照合: [0-9]{4}-[0-9]{2}-[0-9]{2}$' docs/CONSUMER-GUIDE.md` が 1 件だけ当たることで確かめる
- [x] 1.2 design D5 の 1〜5 (読み手と前提、リポジトリの形、値の置き方、置き場所の判断、Homebrew) を書く。各節が家の形・理由・前提の順になっていて、読み手への指示 (「〜せよ」「所有者に確かめる」) が無いことを読み返して確かめる
- [x] 1.3 design D5 の 6 (Claude Code) を書く。コード片は家の構成の現在の宣言から固有名を抜いて作り、MCP のキーは「別ファイルから読む形」だけを載せる (キーのファイルは開かない)。ステータスラインの本体は全文を `<details>` で載せる。`rg -n -i 'readFile' docs/CONSUMER-GUIDE.md` で、キーの行が値ではなくファイルの参照であることを確かめる
- [x] 1.4 design D5 の 7〜11 (日々の運用、秘密、core を直したいとき、申し送り、家にあって書かないもの) を書く。申し送りの節に、会社の固有名を含まない形で書くこと、人間が持ち出すこと、利用側の端末には公開の前の検査が無いことがあることを確かめる
- [x] 1.5 core の文書の説明を写していないことを確かめる: design D4 の表の各話題について、手引きがリンクで参照していて、core の表や手順をそのまま持っていないことを読み比べる
- [x] 1.6 手引きのリンクをすべて抽出し (`rg -o '\]\([^)]+\)' docs/CONSUMER-GUIDE.md`)、相対パスのファイルが在ること、`#` の付いたリンクの見出しが core の `README.md` / `CLAUDE.md` に在ることを突き合わせる

## 2. README と CLAUDE.md から案内する (1 コミット: `docs: README と CLAUDE.md から利用側の手引きへ案内する (add-consumer-guide)`)

- [x] 2.1 `README.md` の冒頭の段落の後に手引きへの 1 文の案内を足し、「ファイル / ディレクトリ」の表に `docs/CONSUMER-GUIDE.md` の行を足す (design D8)。`rg -n 'CONSUMER-GUIDE' README.md` が 2 件当たることで確かめる
- [x] 2.2 `CLAUDE.md` の冒頭の段落の文書の案内に、利用側のリポジトリの作り方と運用は `docs/CONSUMER-GUIDE.md` と足す (design D8)。`rg -n 'CONSUMER-GUIDE' CLAUDE.md` が当たることで確かめる

## 3. 公開の前の検査 (所有者の端末で)

- [x] 3.1 core のクローンで `<家の構成のクローン>/scripts/check-core.sh ../dotfiles` を実行し (家の構成のクローンが隣にある所有者の端末で)、終了コードが 0 であることを確かめる。当たったら語の一覧を変えず、手引きの文章を役割の名前に書き直して、再び 0 になるまで繰り返す
- [x] 3.2 コミットメッセージとブランチ名も同じ検査に通す (`git log --format=%B main..HEAD | <家の構成のクローン>/scripts/check-core.sh -`、`git branch --show-current | <家の構成のクローン>/scripts/check-core.sh --names`)。どちらも 0 であることを確かめる
- [x] 3.3 手引きに家のリポジトリのコミットのハッシュが無いことを確かめる: `rg -n '\b[0-9a-f]{7,40}\b' docs/CONSUMER-GUIDE.md` の当たりがすべて core のコミットか、ハッシュでない語であることを目で確かめる
- [x] 3.4 語の一覧に無い私的な情報 (家でだけ使うアプリとツールの名前、家のほかのリポジトリの名前、家のユーザー名) が無いことを、家の構成の `modules/home/packages.nix`、`modules/darwin/homebrew.nix`、`modules/home/default.nix` の値と手引きを突き合わせて確かめる (キーのファイルは開かない)
- [x] 3.5 `openspec validate add-consumer-guide --strict` が通ることを確かめる
- [x] 3.6 モジュールを変えていないことを確かめる: `git diff --stat main -- modules flake.nix ssh` が空であること (drvPath の照合は要らない)

## 4. archive と PR

- [x] 4.1 `openspec archive add-consumer-guide` で `openspec/specs/consumer-guide/spec.md` を作り、Purpose が spec の `## Purpose` のとおりであることを確かめる。archive したものに 3.1 の検査を再び通す (1 コミット: `docs: add-consumer-guide を archive して specs に反映する`)
- [ ] 4.2 PR の本文を書き、`<家の構成のクローン>/scripts/check-core.sh -` に本文を通して 0 であることを確かめてから PR を出す。本文に利用側の構成の名前を書かない
- [ ] 4.3 レビューを受けてマージする。利用側の lock の更新は急がない (モジュールは変わらない)
