## Why

`docs/CONSUMER-GUIDE.md` (`add-consumer-guide`) は、会社の構成を core だけが見える端末のエージェントが作ることを
前提に、家の Claude Code の宣言 (6 節、346 行) を載せている。会社の環境では Claude Code を使わないことになり、
core を使う利用側のうち Claude Code を使うのは家だけになった。6 節の知見はすべて家の文書 (家の `README.md` と
`CLAUDE.md`) にもあるので、core に残すと読み手の無い写しを家の CI が毎 PR で照合し続けることになる。

## What Changes

- **6 節「Claude Code を宣言する場合の家の形」を手引きから削る。** 7〜11 節を繰り上げ、6 節を指す箇所
  (2 節の構造の木、`anthropic-skills` の input の例、cask の例、7 節の assertion と herdr の skill の注意、8 節の
  `builtins.readFile`) を直す。家へ新しく書き足す知見は無い (6 節の内容は家の文書にすでにある)。
- **手引きの読み手を「人か、エージェント」に広げる。** 1 節の読み手の記述、2 節の `CLAUDE.md` の小節と構造の木の
  `CLAUDE.md` の行は、エージェントに core の `CLAUDE.md` を読ませる場合の形として書く。7 節・9 節・10 節の
  エージェント前提の文も同じ扱いにする。
- **初回の手順 (7 節) から Claude Code の native インストーラの行を外す。** 2 節の `flake.nix` の例から
  `anthropic-skills` の input を外す。
- **8 節の秘密の扱い** は、MCP のキーの例を 6 節に頼らない書き方に直す (値を別のファイルに分け、エージェントが
  宣言を読むたびに値が文脈へ入らないようにする)。原則は特定のエージェント製品に依らないので残す。
- spec `consumer-guide` から、Claude Code を名指しする要件と Scenario を外し、製品名の無い形にする。
- 冒頭の `最終照合:` の日付を、家の構成と突き合わせた日に改める。
- 範囲に入れないもの: core の `CLAUDE.md`、モジュールのコメント、`terminal-tooling` の要件 (core の振る舞いの根拠で、
  Claude Code の宣言ではない)。`README.md` の「移行 (`move-claude-code-to-consumer`)」の節も残す (別件)。

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `consumer-guide`: 読み手を「core だけが見える端末で利用側のリポジトリを作って運用する人かエージェント」にする。
  手引きが覆う範囲から「Claude Code を宣言する場合の形」を外し、特定のエージェント製品の宣言を手引きに載せない
  要件にする。「Claude Code の宣言を載せる」の Scenario を、製品名の無い「利用側のツールの宣言を載せる」に替える。

## Impact

- **文書:** `docs/CONSUMER-GUIDE.md` (6 節の削除、節番号、読み手の記述、相互参照、最終照合の日付)。`README.md` と
  `CLAUDE.md` の手引きへの案内は変わらない。
- **コード:** なし。モジュール、option、生成物は変わらない (drvPath の照合は要らない)。
- **利用側 (家):** 手引きのレビューの対象のパスの一覧から、ステータスラインのディレクトリを外せる (6 節にしか
  写っていなかった)。家の側の lock の更新の PR で行う。core はそれを参照しない。
