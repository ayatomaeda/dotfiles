## MODIFIED Requirements

### Requirement: マルチプレクサの連携で Claude Code の設定を宣言外に変更しない

利用側が Claude Code の設定を宣言から生成している環境では、システムは、マルチプレクサの連携コマンド (`herdr integration install claude` 等) によって、`~/.claude/settings.json` や `~/.claude/hooks/` を宣言外で変更してはならない (MUST NOT)。連携が必要な場合は、追加される hook とスクリプトを、Claude Code の設定を宣言したリポジトリで管理する変更として行わなければならない (SHALL)。

`~/.claude/settings.json` は宣言から生成した読み取り専用の実体なので、連携コマンドによる hook の追加は保存されず、hook スクリプトだけが宣言外に残る (`retire-out-of-store-symlinks`)。core は Claude Code の設定を持たないが、herdr は core が導入するので、この要件は core に置く。

#### Scenario: herdr 導入直後の Claude Code 設定

- **WHEN** Claude Code の設定を宣言した利用側で、herdr を導入して switch した
- **THEN** 利用側の `programs.claude-code.settings` に herdr の hook が含まれない
- **AND** `~/.claude/hooks/herdr-agent-state.sh` が存在しない

### Requirement: 暗黙の外部依存を宣言に引き上げる

システムは、リポジトリが管理するスクリプト・設定が実行時に依存するコマンドを、**Nix 構成で宣言**しなければならない (SHALL)。OS 同梱のコマンドが偶然 `PATH` に存在することに依存してはならない (MUST NOT)。

`/usr/bin` に存在するコマンドは flake の pin の外にあり、OS の更新で版が変わっても構成は何も検知しない。

利用側が管理するスクリプトは、core が宣言したコマンドに依存してよい (MAY)。その場合は、core の宣言を前提にすることを利用側のコメントに書く。

#### Scenario: 管理下スクリプトの依存

- **WHEN** リポジトリが管理するスクリプトが外部コマンドを呼ぶ
- **THEN** そのコマンドが `home.packages` または `programs.*` により、そのリポジトリか core で宣言されている
- **AND** そのコマンドの解決先が Nix プロファイル配下であることを確認できる

#### Scenario: 環境変数が指すコマンド

- **WHEN** `EDITOR` のような環境変数でコマンドを指定する
- **THEN** 指定先は Nix 構成が宣言したコマンドである
