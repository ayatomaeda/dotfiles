## Why

このリポジトリは現在 Homebrew (`dot_Brewfile`) と chezmoi の 2 系統で macOS 環境を管理しているが、パッケージのバージョンがロックされず、新しい Mac をセットアップするたびに手作業が発生し、環境を丸ごと再現できない。Nix (flakes + nix-darwin + home-manager) に移行することで、CLI・GUI アプリ・dotfiles を単一の `flake.nix` から宣言的に管理し、`flake.lock` によって再現性を保証する。あわせて所有者が Nix を学ぶ足がかりにする。

## What Changes

- **BREAKING**: パッケージ管理を Homebrew (`brew bundle`) 主導から Nix (flakes + nix-darwin) 主導へ移行する。cask / Mac App Store アプリは nix-darwin の `homebrew.*` モジュール経由で宣言的に管理し、Homebrew は「裏方」として残す。
- **BREAKING**: dotfiles の管理を chezmoi から home-manager へ移行し、最終的に chezmoi と `dot_*` / `private_dot_*` ファイルを撤去する。
- CLI ツール (`git` `tmux` `node` `ffmpeg` `gh` `ghq` `uv` `yt-dlp` `swiftlint` 等) を Nix ネイティブパッケージへ移す。nixpkgs に存在しないもの (`appium` `periphery` 等) は Homebrew に残すことを許容する。
- `flake.nix` を入口として、nix-darwin (システム) と home-manager (ユーザー) を単一リポジトリに統合する。home-manager は nix-darwin のモジュールとして組み込み、`darwin-rebuild switch` 一発で system と home を同時適用する。
- インストーラは Determinate Systems 製を採用し、Determinate Nix と nix-darwin の Nix 管理の競合を design で明示的に解決する。
- 段階移行 (土台 → CLI → GUI/mas → dotfiles → 撤去) を採用し、各段階で `switch` して動作確認・コミットできるようにする。

## Capabilities

### New Capabilities
- `system-bootstrap`: 新しい Mac (またはクリーン環境) で、Nix インストールから `darwin-rebuild switch --flake .#<host>` 一発で環境全体を再現するブートストラップ手順と、Determinate Nix / nix-darwin の Nix 管理境界に関する要求。
- `package-management`: パッケージをどこで・どう宣言し導入するかの要求。CLI は Nix ネイティブ、GUI (cask) と Mac App Store アプリは nix-darwin の `homebrew.*` モジュール経由で宣言的に管理し、未管理アプリは `onActivation.cleanup` で掃除する。
- `dotfiles-management`: dotfiles を home-manager で宣言的に管理する要求。`programs.*` の native モジュール (zsh/git/tmux) と、頻繁に編集する生ファイル (ghostty/ssh/claude) の out-of-store symlink を使い分ける。

### Modified Capabilities
<!-- 既存の main spec は無いため、変更対象の capability は無し。 -->

## Impact

- **追加ファイル**: `flake.nix`, `flake.lock`, `darwin.nix`, `home.nix`（`openspec/specs/` ではなく dotfiles リポジトリ直下）。
- **撤去ファイル (移行完了後)**: `dot_Brewfile`, `dot_zshrc`, `private_dot_gitconfig`, `private_dot_ssh/`, `private_dot_claude/`, `dot_config/`, `.chezmoiignore`。
- **依存/ツール**: Determinate Nix (installer)、nix-darwin、home-manager、nixpkgs。Homebrew は cask / mas 用に残存（`mas` CLI 含む）。chezmoi は撤去。
- **ドキュメント**: `README.md` の新 PC セットアップ手順を chezmoi 版から Nix 版へ更新。
- **非対象 (non-goals)**: nix-homebrew による Homebrew 本体の宣言化、NixOS/Linux 対応、`nix develop` によるプロジェクト別開発シェル、既存 CLI 全ツールの `programs.*` 完全モジュール化。
