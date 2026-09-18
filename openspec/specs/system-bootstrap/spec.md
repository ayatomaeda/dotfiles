# system-bootstrap Specification

## Purpose
Nix 本体とその設定の管理の境界。Determinate Nix を前提にし、nix-darwin には Nix 本体を管理させないことで、適用時の衝突を避ける。

## Requirements
### Requirement: Determinate Nix と nix-darwin の管理境界

システムは、Determinate Systems 製インストーラを前提とし、Nix 本体の管理主体を明示しなければならない (SHALL)。既定では nix-darwin の Nix 管理を無効化 (`nix.enable = false`) し、Nix 本体は Determinate に委ねる。

#### Scenario: 管理競合の回避

- **WHEN** Determinate Nix 環境で `darwin-rebuild switch` を実行する
- **THEN** nix-darwin は Nix 本体/設定の管理を試みず、`Determinate detected, aborting activation` エラーを起こさずに適用が完了する

