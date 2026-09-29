## Why

`use-upstream-nix` で、Determinate Nix が入った Mac を upstream の Nix へ入れ替える手順を README に書き、spec の要件にした。
core を使う Mac はすべて入れ替え終えたので、この手順を読む人はもういない。一度きりの作業の手順を README に置き続けると、
日々の運用の説明に埋もれ、読む人に「まだやることがある」と誤読させる。

## What Changes

- README の「Determinate Nix から upstream の Nix への入れ替え」の節を削る。「利用側が与えるもの」の表の、その節への
  リンクを外す。
- `modules/darwin/default.nix` のコメントの「入れ替えの手順は README」を、手順の在りかを示す書き方に改める。
- spec の要件「Determinate Nix からの入れ替えの手順を示す」を削る。手順は `use-upstream-nix` の時点の README
  (git の履歴) と archive した design に残る。
- `use-upstream-nix` の archive の tasks の「6.4 マージする」に印を付ける (マージ済み。archive をマージの前にコミットした
  ため印を付ける機会が無かった)。

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `system-bootstrap`: 「Determinate Nix からの入れ替えの手順を示す」を削る。Purpose から入れ替えの手順への言及を除く。

## Impact

- **文書:** `README.md`、`modules/darwin/default.nix` のコメント。
- **構成:** 変わらない (コメントだけ)。
