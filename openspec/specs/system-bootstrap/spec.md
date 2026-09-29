# system-bootstrap Specification

## Purpose
Nix の本体とその設定の管理。upstream の Nix を前提にし、Nix の設定と daemon を nix-darwin に管理させる。
## Requirements
### Requirement: upstream の Nix を nix-darwin が管理する

システムは、Nix の本体に NixOS が配布する upstream の Nix を前提にしなければならない (SHALL)。Determinate Nix を前提にしてはならず、Determinate Systems が配布するインストーラ、daemon、action を必要としてはならない (MUST NOT)。

Nix の設定 (`/etc/nix/nix.conf`、`/etc/nix/registry.json`) と daemon は nix-darwin が管理しなければならない (SHALL)。core は nix-darwin の Nix の管理を無効にしてはならない (MUST NOT)。

core は `nix-command` と `flakes` を有効にしなければならない (SHALL)。upstream の Nix はどちらも既定で無効であり、どの利用側も flake で構成を適用するためである。

core は channel を無効にしなければならない (SHALL)。構成は flake だけで扱う。`nixpkgs` の参照 (`nix search nixpkgs`、`nix shell nixpkgs#…`、`NIX_PATH` の `nixpkgs`) は、nix-darwin が利用側の `flake.lock` の nixpkgs に固定した registry で解決されなければならない (SHALL)。

#### Scenario: upstream の Nix の Mac での適用

- **WHEN** upstream の Nix を入れた Mac で、利用側の構成に `darwin-rebuild switch` を実行する
- **THEN** 適用が完了し、`/etc/nix/nix.conf` と launchd の `org.nixos.nix-daemon` が nix-darwin の管理になる
- **AND** `nix --version` は Determinate Nix を示さない

#### Scenario: flakes の有効化

- **WHEN** switch した後の新しいシェルで `nix config show experimental-features` を実行する
- **THEN** `nix-command` と `flakes` が含まれる

#### Scenario: nixpkgs の参照が lock と一致する

- **WHEN** switch した後に `nix flake metadata nixpkgs --json` の `.locked.narHash` を取る
- **THEN** 利用側の `flake.lock` の `nodes.nixpkgs.locked.narHash` と一致する
- **AND** `NIX_PATH` に channel のパスが無い

#### Scenario: Determinate Nix が残っている Mac

- **WHEN** Determinate Nix が入ったままの Mac で、この core を使う構成に switch する
- **THEN** nix-darwin の検査で activation が止まり、`/etc` と launchd のサービスは変わらない
- **AND** system のプロファイルには新しい世代が残るので、再起動の前に `darwin-rebuild --rollback` で戻す

