## MODIFIED Requirements

### Requirement: CLI ツールは Nix ネイティブで宣言する

システムは、nixpkgs に存在する CLI ツールを Nix ネイティブパッケージ (`home.packages` または `environment.systemPackages`) として宣言的に導入しなければならない (SHALL)。`homebrew.brews` は **Homebrew でしか導入できないもの**に限定しなければならない (SHALL)。

あるツールを Homebrew に置くことを許容するのは、そのツールが nixpkgs に存在しない場合に限る。一度 Homebrew に置いたツールも、nixpkgs に追加された時点で Nix 側へ引き取らなければならない (SHALL)。

#### Scenario: CLI ツールの Nix 導入

- **WHEN** `switch` を実行する
- **THEN** 宣言された CLI ツールが Nix プロファイル経由で PATH 上に導入される
- **AND** 同じツールを Homebrew formula から重複導入しない

#### Scenario: nixpkgs に存在しない CLI の扱い

- **WHEN** あるツールが pin 済みの nixpkgs に存在しない
- **THEN** そのツールは `homebrew.brews` に列挙して Homebrew 経由で導入してよい (MAY)
- **AND** なぜ Homebrew でなければならないかを宣言箇所のコメントに記録する

#### Scenario: nixpkgs に追加されたツールの引き取り

- **WHEN** `homebrew.brews` に置いているツールが pin 済みの nixpkgs に存在することを確認した
- **THEN** そのツールを `home.packages` へ移し、`homebrew.brews` から削除する
- **AND** 確認は **`flake.lock` が pin している rev に対する評価**で行う (どの rev を見たかを明示するため。`nix search nixpkgs` の結果は、その Mac の registry が指す rev に依存する)
