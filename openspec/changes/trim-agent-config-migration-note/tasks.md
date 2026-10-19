# Tasks

## 1. README と手引きを直す (1 コミット: `docs: README から済んだ移行の案内を外す (trim-agent-config-migration-note)`)

- [x] 1.1 `README.md` の「エージェントの設定は利用側が持つ」から「以前の core からの移行」の太字の段落と 4 項目を外し、以前の宣言と手引きの「日々の運用」への案内を 1 段落で置く。`rg -n 'install.sh|package = null|cleanup = "uninstall"' README.md` がこの節に当たらないことで確かめる
- [x] 1.2 `docs/CONSUMER-GUIDE.md` の「日々の運用」の「(core の README の「エージェントの設定は利用側が持つ」の移行)」を、README の節に頼らない文に直す。`rg -n 'の移行\)' docs/CONSUMER-GUIDE.md` が 0 件で、`最終照合:` が 2026-10-19 のままであることで確かめる
- [x] 1.3 README の新しいリンク先 (`docs/CONSUMER-GUIDE.md#6-日々の運用`) の見出しが手引きに在ること、手引きから README へのリンク (`#エージェントの設定は利用側が持つ`) の見出しが残っていることを `rg` で確かめる

## 2. 公開の前の検査 (所有者の端末で)

- [x] 2.1 `<家の構成のクローン>/scripts/check-core.sh ../dotfiles` が 0 で終わる。コミットメッセージとブランチ名も同じ検査に通す
- [x] 2.2 `git diff --stat main -- modules flake.nix ssh` が空であることを確かめる (drvPath の照合は要らない)

## 3. archive と PR

- [ ] 3.1 `openspec validate trim-agent-config-migration-note --strict` が通ることを確かめ、`openspec archive` する (1 コミット: `docs: trim-agent-config-migration-note を archive する`)
- [ ] 3.2 PR の本文を語の検査に通してから PR を出す
