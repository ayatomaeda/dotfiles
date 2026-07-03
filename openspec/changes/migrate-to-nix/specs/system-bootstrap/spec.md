## ADDED Requirements

### Requirement: Flake ベースの単一入口

システムは `flake.nix` を単一の入口として持ち、`nixpkgs`・`nix-darwin`・`home-manager` を inputs として宣言し、`flake.lock` によって全入力のリビジョンをピン留めしなければならない (SHALL)。

#### Scenario: flake.lock による再現性

- **WHEN** `flake.lock` をコミットした状態で別マシンが同じコミットをチェックアウトして評価する
- **THEN** すべての入力が同一リビジョンに解決され、同一の構成が再現される

#### Scenario: home-manager を nix-darwin モジュールとして統合

- **WHEN** `flake.nix` の `darwinConfigurations.<host>` が評価される
- **THEN** home-manager が nix-darwin のモジュールとして読み込まれ、system 構成と home 構成が単一の構成として組み立てられる

### Requirement: 単一コマンドでのブートストラップ

システムは、Nix インストール後に単一コマンド `darwin-rebuild switch --flake .#<host>` で system と home の両方を適用できなければならない (SHALL)。

#### Scenario: 新環境での初回適用

- **WHEN** Determinate Nix をインストール済みのクリーンな Mac で `darwin-rebuild switch --flake .#<host>` を実行する
- **THEN** CLI ツール・GUI アプリ・Mac App Store アプリ・dotfiles が宣言どおりに導入・配置される

#### Scenario: ホスト名の解決

- **WHEN** 実行環境のホスト名が `flake.nix` の `darwinConfigurations` のキーと一致する
- **THEN** `--flake .#<host>` が正しい構成に解決される
- **AND** 一致しない場合は解決エラーとなり、正しいホスト名の指定を促す

### Requirement: Determinate Nix と nix-darwin の管理境界

システムは、Determinate Systems 製インストーラを前提とし、Nix 本体の管理主体を明示しなければならない (SHALL)。既定では nix-darwin の Nix 管理を無効化 (`nix.enable = false`) し、Nix 本体は Determinate に委ねる。

#### Scenario: 管理競合の回避

- **WHEN** Determinate Nix 環境で `darwin-rebuild switch` を実行する
- **THEN** nix-darwin は Nix 本体/設定の管理を試みず、`Determinate detected, aborting activation` エラーを起こさずに適用が完了する

### Requirement: 世代ロールバック

システムは、直前の構成へロールバックする手段を提供しなければならない (SHALL)。

#### Scenario: 適用失敗からの復旧

- **WHEN** 新しい構成の `switch` 後に問題が発生する
- **THEN** `darwin-rebuild --rollback` により直前の世代へ戻せる
