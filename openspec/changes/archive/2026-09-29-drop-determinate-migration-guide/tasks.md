## 1. 文書

- [x] 1.1 README の「Determinate Nix から upstream の Nix への入れ替え」の節を削り、「利用側が与えるもの」の表のリンクを、手順の在りか (コミット `ba5dfb1` の README) を示す文に替える
- [x] 1.2 `modules/darwin/default.nix` のコメントの「入れ替えの手順は README」を同じく改め、example の評価の drvPath が変わらないことを確かめる
- [x] 1.3 `use-upstream-nix` の archive の tasks の 6.4 に印を付ける

## 2. archive とマージ

- [x] 2.1 私的な語の検査をこのブランチの成果物とコミットメッセージにかける
- [x] 2.2 `openspec archive drop-determinate-migration-guide` を実行し、`openspec/specs/system-bootstrap/spec.md` の Purpose から入れ替えの手順への言及を除く
- [ ] 2.3 PR を作り、CI が通ることを確かめる
