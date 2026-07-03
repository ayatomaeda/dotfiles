## ADDED Requirements

### Requirement: CLI ツールは Nix ネイティブで宣言する

システムは、nixpkgs に存在する CLI ツールを Nix ネイティブパッケージ (`home.packages` または `environment.systemPackages`) として宣言的に導入しなければならない (SHALL)。対象には `git` `tmux` `node` `ffmpeg` `gh` `ghq` `uv` `yt-dlp` `swiftlint` を含む。

#### Scenario: CLI ツールの Nix 導入

- **WHEN** `switch` を実行する
- **THEN** 宣言された CLI ツールが Nix プロファイル経由で PATH 上に導入される
- **AND** 同じツールを Homebrew formula から重複導入しない

#### Scenario: nixpkgs に存在しない CLI の扱い

- **WHEN** あるツール (例: `appium` `periphery`) が nixpkgs に存在しない
- **THEN** そのツールは `homebrew.brews` に列挙して Homebrew 経由で導入してよい (MAY)

### Requirement: GUI アプリと Mac App Store アプリは homebrew モジュールで宣言する

システムは、GUI アプリ (cask) と Mac App Store アプリ (mas) を nix-darwin の `homebrew.*` モジュールを通じて宣言的に管理しなければならない (SHALL)。`homebrew.enable = true` とし、cask は `homebrew.casks`、Mac App Store アプリは `homebrew.masApps`、mas 導入に必要な `mas` CLI は `homebrew.brews` に宣言する。

#### Scenario: cask の宣言的導入

- **WHEN** `homebrew.casks` に列挙したアプリで `switch` を実行する
- **THEN** 列挙された cask が Homebrew 経由で導入される

#### Scenario: Mac App Store アプリの宣言的導入

- **WHEN** `homebrew.masApps` にアプリ名と ID を宣言して `switch` を実行する
- **THEN** `mas` CLI 経由で該当アプリが導入される

### Requirement: 未管理パッケージの掃除

システムは、`homebrew.onActivation.cleanup` により、宣言に列挙されていない Homebrew パッケージを検出・除去できなければならない (SHALL)。移行初期は非破壊的な設定 (`"check"` または `"uninstall"`) を用い、全項目の列挙完了を確認してから `"zap"` へ厳格化してよい (MAY)。

#### Scenario: 未列挙アプリの検出

- **WHEN** `cleanup = "check"` の状態で、宣言に無い cask/formula が既に導入されている
- **THEN** activation が失敗し、未管理パッケージの存在が報告される

#### Scenario: 未列挙アプリの除去

- **WHEN** `cleanup = "uninstall"` (または `"zap"`) で `switch` を実行する
- **THEN** 宣言に無い Homebrew パッケージが除去される

### Requirement: パッケージ宣言の単一の情報源

システムは、パッケージ構成の情報源を Nix (`flake.nix` とその配下) に一本化しなければならない (SHALL)。移行完了後、`dot_Brewfile` を情報源として使用してはならない (MUST NOT)。

#### Scenario: Brewfile の廃止

- **WHEN** 移行が完了している
- **THEN** パッケージの追加・削除は Nix 構成の編集と `switch` によってのみ行われ、`dot_Brewfile` は削除されている
