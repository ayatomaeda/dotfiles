## MODIFIED Requirements

### Requirement: マルチプレクサの連携で Claude Code の設定を宣言外に変更しない

利用側が Claude Code の設定を宣言から生成している環境では、システムは、マルチプレクサの連携コマンド (`herdr integration install claude` 等) によって、`~/.claude/settings.json` や `~/.claude/hooks/` を宣言外で変更してはならない (MUST NOT)。連携が必要な場合は、追加される hook とスクリプトを、Claude Code の設定を宣言したリポジトリで管理する変更として行わなければならない (SHALL)。

`~/.claude/settings.json` は宣言から生成した読み取り専用の実体なので、連携コマンドによる hook の追加は保存されず、hook スクリプトだけが宣言外に残る (`retire-out-of-store-symlinks`)。core は Claude Code の設定を持たないが、herdr は core が導入するので、この要件は core に置く。

#### Scenario: herdr 導入直後の Claude Code 設定

- **WHEN** Claude Code の設定を宣言した利用側で、herdr を導入して switch した
- **THEN** 利用側の `programs.claude-code.settings` に herdr の hook が含まれない
- **AND** `~/.claude/hooks/herdr-agent-state.sh` が存在しない
