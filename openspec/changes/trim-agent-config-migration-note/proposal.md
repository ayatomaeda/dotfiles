## Why

core の `README.md`「エージェントの設定は利用側が持つ」の後半「以前の core からの移行 (`move-claude-code-to-consumer`)」は、
2026-10-07 に core が Claude Code の設定と cask を外したとき、lock を上げる利用側が困らないための案内だった
(`move-claude-code-to-consumer` design の Risks)。その移行は家で済み、Claude Code を使う利用側は家だけになった
(`drop-claude-code-from-consumer-guide`)。案内を読む人はもう居ないのに、特定の製品の導入と宣言の手順が core の README に
残っている。

## What Changes

- `README.md` の「エージェントの設定は利用側が持つ」から、移行の案内の 4 項目 (lock と同じコミットで宣言する、native
  インストーラと `package = null`、cask `"claude"` を足す、assertion を置く) を外す。前半の原則 (core は特定のエージェント
  製品の設定を持たない。一般的な道具は core にある) は残す。
- 以前の core が宣言していたことと、core が宣言を外す変更を利用側で受ける手順が手引きの「日々の運用」にあることを、
  1 段落で残す (製品に依らない手順は手引きがすでに持つ)。
- `docs/CONSUMER-GUIDE.md` の「日々の運用」で、この移行の節を指している括弧書きを、節に頼らない文に直す。手引きの内容は
  変わらず、`最終照合:` は同じ日 (2026-10-19) のまま。

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

(なし。`dotfiles-management` の「特定のエージェント製品の設定は利用側が持つ」の原則は変わらず、README の移行の案内を
求める要件は無い。`skip_specs: true`)

## Impact

- **文書:** `README.md` (1 節の後半)、`docs/CONSUMER-GUIDE.md` (1 文の参照)。
- **コード:** なし。モジュール、option、生成物は変わらない (drvPath の照合は要らない)。
- **利用側 (家):** 家の文書はこの節を参照していない (grep で確認)。lock の更新は急がない。
