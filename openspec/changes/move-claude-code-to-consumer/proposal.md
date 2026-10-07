## Why

core は「どの環境でも使うもの」だけを置く場所だが、Claude Code の設定 (`settings.json`、プラグイン、ステータスライン) と
Claude のデスクトップ版の cask は、core を使うすべての利用側に入り、利用側では外せない。使うエージェントは環境によって違う
(Claude Code を使わない環境もありうる)。特定のエージェント製品の設定は、それを使う利用側が持つべきである。

一方、エンジニアが日常的に使う道具 (`jq`、`ripgrep`、`fd`、`herdr` など) は、どのエージェントを使う環境でも使うので core に残す。

## What Changes

- **BREAKING:** `modules/common/claude-code.nix` を削除し、`homeModules.default` は `programs.claude-code` を宣言しなくなる。
  利用側は lock を更新すると `~/.claude/settings.json` が生成されなくなる。Claude Code を使う利用側は、自分の構成で宣言する。
- **BREAKING:** `claude/statusline-command.sh` を削除する (利用側へ移す)。
- **BREAKING:** `modules/darwin/homebrew.nix` の cask のリストから `"claude"` (デスクトップ版) を外す。
  `homebrew.onActivation.cleanup = "uninstall"` の利用側は、自分のリストに足さないと次の switch で削除される。
- `programs.jq` と `programs.ripgrep` は core に残す。コメントの導入根拠を、Claude Code 固有の経緯 (ステータスラインが呼ぶ、
  Claude Code の内部の `rg` しか無かった) から、エージェントと人間が日常的に使うという一般的な理由に書き直す。
- シェルスナップショットへの配慮 (alias で既存のコマンド名を奪わない、`TRAPINT` の非対話の分岐、tmux の注記) は
  非対話のエージェント全般のための性質なので、core に残す。
- 文書 (README、`docs/GUIDE.md`、CLAUDE.md) から Claude Code の設定の置き場所と、Claude Code に固有の注意 (`marketplaces` を
  使わない、`/config` が保存されない) を外し、利用側への移行の注記を足す。
- 利用側 (所有者の家の構成) に、削除したものと同じ宣言を移す。lock の更新と同じコミットで行う。

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `dotfiles-management`: core が特定のエージェント製品の設定と、その製品のためだけの依存を持たない要件を足す。一般的な道具は
  core に置く。「保存されない操作を文書に書く」の例示から Claude Code を外す (書く場所は、そのアプリを宣言した利用側の文書になる)。
  「実行可能なスクリプトの配置」の Scenario の例を、core に残るスクリプト (git の署名のラッパー) に改める。
- `terminal-tooling`: 「暗黙の外部依存を宣言に引き上げる」の Scenario から `claude/statusline-command.sh` を外し、利用側の
  スクリプトが core の宣言に頼ってよいことを足す。「マルチプレクサの連携で Claude Code の設定を宣言外に変更しない」の
  Scenario が名指しする `modules/common/claude-code.nix` を改める (core は Claude Code の設定を持たない)。

## Impact

- **コード:** `modules/common/claude-code.nix` (削除)、`modules/common/default.nix` (import を外す)、`claude/` (削除)、
  `modules/common/terminal.nix` (`jq` と `rg` のコメント)、`modules/darwin/homebrew.nix` (cask)。
- **文書:** `README.md`、`docs/GUIDE.md`、`CLAUDE.md`。
- **利用側:** Claude Code を使う利用側は、`programs.claude-code`、ステータスラインのスクリプト、cask `"claude"` を自分で宣言する。
  core の `jq` と `git` はそのまま使える。lock の更新と同じコミットで行えば、設定が消える世代も cask の削除も起きない。
- **生成物:** 所有者の家の構成では、移した後の `~/.claude/settings.json`、ステータスラインのスクリプト、`home-manager-path`、
  Brewfile の行の集合が変わらない。Brewfile の行の順序だけが変わり、drvPath は一致しない (design)。
