# dotfiles

macOS (Apple Silicon) の環境を **Nix flake + nix-darwin + home-manager** で宣言的に管理する。
`flake.lock` により再現性を保証し、`darwin-rebuild switch` 一発で system・CLI・GUI アプリ・dotfiles を再現する。

## 構成

| ファイル / ディレクトリ | 役割 |
|---|---|
| `flake.nix` | 入口。inputs (`nixpkgs-unstable` / `nix-darwin` / `home-manager`) と `darwinConfigurations` |
| `darwin.nix` | システム設定。Nix 設定 / `homebrew` モジュール (cask・mas・brew-only formula) |
| `home.nix` | ユーザー設定。`home.packages` (CLI) と `programs.*` (zsh/git/tmux) |
| `config/` `ssh/` `claude/` | out-of-store symlink の実体 (ghostty / ssh / claude statusline)。編集は即反映 |

- **CLI ツール**は Nix ネイティブ (`home.packages` / `programs.*`)。
- **GUI アプリ (cask) と Mac App Store アプリ (mas)** は Nix では扱えないため、`homebrew` モジュール経由で宣言的に Homebrew を駆動する (Homebrew は裏方として残る)。
- `nixpkgs` に無い `appium` / `periphery` は `homebrew.brews`。
- **Claude Code は管理対象外** — Homebrew 管理下だと自動更新が無効化されるため、自動更新される native インストーラ (`curl -fsSL https://claude.ai/install.sh | bash`) で管理する。

## 日常の使い方

設定を編集して適用する:

```sh
# flake.nix / darwin.nix / home.nix を編集後
$ sudo darwin-rebuild switch --flake ~/git/github.com/ayatomaeda/dotfiles#KeisukenoMac-Studio
```

`config/` `ssh/` `claude/` 配下の生ファイルは out-of-store symlink なので、編集すれば rebuild なしで反映される。

適用前に評価・ビルドだけ確認したいとき (非破壊):

```sh
$ darwin-rebuild build --flake .#KeisukenoMac-Studio
```

入力を更新する (nixpkgs 等を最新へ):

```sh
$ nix flake update            # flake.lock を更新
$ sudo darwin-rebuild switch --flake .#KeisukenoMac-Studio
```

## ロールバック

問題が起きたら直前の世代へ戻せる:

```sh
$ sudo darwin-rebuild --rollback
```

`flake.lock` を git で戻して再 switch すれば、入力のバージョンごと復元できる。

## 新しい Mac でのセットアップ

```sh
# 1. Determinate Nix をインストール (flakes 有効)
$ curl -fsSL https://install.determinate.systems/nix | sh -s -- install

# 2. このリポジトリを clone (out-of-store symlink はこのパスを参照する)
$ mkdir -p ~/git/github.com/ayatomaeda
$ git clone <this-repo> ~/git/github.com/ayatomaeda/dotfiles
$ cd ~/git/github.com/ayatomaeda/dotfiles

# 3. ホスト名を設定に合わせる (または flake.nix の hostname を実機に合わせる)
$ scutil --get LocalHostName        # 例: KeisukenoMac-Studio

# 4. 適用 (nix-darwin 未導入の初回は nix run で bootstrap)
$ sudo nix run nix-darwin -- switch --flake .#KeisukenoMac-Studio
#   2 回目以降:
$ sudo darwin-rebuild switch --flake .#KeisukenoMac-Studio

# 5. Claude Code (自動更新版) を別途インストール
$ curl -fsSL https://claude.ai/install.sh | bash
```

> メモ: Determinate Nix が Nix 本体を管理するため、`darwin.nix` では `nix.enable = false` にして競合を避けている。
