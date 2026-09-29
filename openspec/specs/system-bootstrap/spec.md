# system-bootstrap Specification

## Purpose
Nix の本体とその設定の管理。upstream の Nix を前提にし、Nix の設定と daemon を nix-darwin に管理させる。Determinate Nix が入った Mac を入れ替える手順を示す。
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

### Requirement: Determinate Nix からの入れ替えの手順を示す

システムは、Determinate Nix が入った Mac を upstream の Nix へ入れ替える手順を、リポジトリの文書に示さなければならない (SHALL)。手順は次の順でなければならない (SHALL)。(1) nix-darwin の uninstaller で nix-darwin を外す (Determinate のアンインストーラは nix-darwin が入っていると削除を拒否する)。(2) Determinate Nix のアンインストーラで Nix を消す。(3) NixOS の公式のインストーラで flakes を有効にして入れる。(4) 利用側のリポジトリの、core を上げてマージしたコミットで構成を build し、build 結果の `darwin-rebuild` で switch する。

手順は、作業の前に次を示さなければならない (SHALL)。`/nix` が消えてそれより前の世代に戻れないこと。(1) から (4) の間は、nix-darwin が宣言した sshd の設定が外れ、公開鍵認証が効かずパスワード認証を受け付けること。sudo の Touch ID と home-manager の設定 (シェル、ssh、git) が使えないこと。作業を tmux や herdr の外の素のシェルで行うこと。コミットを switch の後に行うこと。

手順は `sudo nix run nix-darwin -- switch` を使ってはならない (MUST NOT)。registry の解決で nix-darwin の master を取り、利用側の `flake.lock` の固定から外れるためである。switch は、利用側のコミットに無い lock から行ってはならない (MUST NOT)。

#### Scenario: 入れ替えの完了

- **WHEN** 所有者が文書の手順で Mac の Nix を入れ替える
- **THEN** その Mac は利用側の `flake.lock` が固定した構成に switch した状態になる
- **AND** `/usr/local/bin/determinate-nixd` が無く、launchd に `systems.determinate.nix-daemon` と `systems.determinate.nix-store` が無い

#### Scenario: リモートの Mac の入れ替え

- **WHEN** 所有者が接続先の Mac を ssh 越しに入れ替えようとする
- **THEN** 文書は、作業中は公開鍵でログインできず、sshd がパスワード認証を受け付けることを作業の前に示している
- **AND** 文書は、既存の接続を閉じずに、uninstaller の後で別の接続からパスワードでログインできることを確かめてから先へ進むよう示している

