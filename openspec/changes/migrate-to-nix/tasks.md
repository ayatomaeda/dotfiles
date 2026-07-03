## 0. 事前確定（着手前の意思決定）

- [ ] 0.1 nixpkgs チャンネル (stable `nixos-25.11` か `nixpkgs-unstable`) を確定する（再現性の核に効くため Phase 1 着手前に決める / Open Question）

## 1. 土台: Nix インストールと最小構成で switch を通す

- [ ] 1.1 Determinate Systems 製インストーラで Nix を導入する (`curl -fsSL https://install.determinate.systems/nix | sh -s -- install`)
- [ ] 1.2 実ホスト名を確認する (`scutil --get LocalHostName`) — `flake.nix` の `darwinConfigurations` キーに使う
- [ ] 1.3 `flake.nix` を作成し、inputs に `nixpkgs` / `nix-darwin` / `home-manager` を宣言、outputs に `darwinConfigurations.<host>` を定義する
- [ ] 1.4 `darwin.nix` に最小のシステム構成を書き、`nix.enable = false;`（Determinate 競合回避）を設定する
- [ ] 1.5 `home.nix` に最小の home-manager 構成を書き、nix-darwin のモジュールとして組み込む
- [ ] 1.6 `darwin-rebuild switch --flake .#<host>` が成功することを確認する（最初の成功体験）
- [ ] 1.7 この時点の `flake.nix` / `flake.lock` / `darwin.nix` / `home.nix` をコミットする

## 2. CLI: formula を Nix ネイティブへ移行

- [ ] 2.1 `nix search` で各 CLI の nixpkgs 提供を確認する（`git` `tmux` `node` `ffmpeg` `gh` `ghq` `uv` `yt-dlp` `swiftlint`）
- [ ] 2.2 nixpkgs にあるものを `home.packages`（または git/tmux は後続の native モジュール）で宣言する
- [ ] 2.3 `appium` / `periphery` の提供有無を確認し、無ければ `homebrew.brews` に残す方針を確定する
- [ ] 2.3a `chezmoi` formula はこの Phase では Nix へ移さず既存 brew のまま残す（Phase 4 の一致確認に使うため。撤去は Phase 5）
- [ ] 2.4 `switch` して各 CLI が Nix 経由で PATH 上に来ることを確認し、対応する formula を `dot_Brewfile` から削除する
- [ ] 2.5 CLI 移行分をコミットする

## 3. GUI/mas: cask・Mac App Store を homebrew モジュールへ移行

- [ ] 3.1 `homebrew.enable = true;` を設定し、`homebrew.casks` に全 cask を列挙する
- [ ] 3.2 `homebrew.masApps` に全 Mac App Store アプリを名前と ID で列挙する（Keynote/Numbers/Pages/Xcode/Kindle/Spark）
- [ ] 3.3 `mas` CLI を `homebrew.brews` に残す
- [ ] 3.4 `homebrew.onActivation.cleanup = "check"`（非破壊）で `switch` し、未列挙アプリが無いことを確認する
- [ ] 3.5 全項目の列挙漏れが無いことを確認後、必要なら `cleanup` を `"uninstall"`/`"zap"` へ厳格化する
- [ ] 3.6 GUI/mas 移行分をコミットする

## 4. dotfiles: home-manager へ移行

- [ ] 4.1 `programs.zsh` を作成し、alias・history オプション・カスタム ssh 関数・`PATH` を移植する
- [ ] 4.2 `programs.git` を作成し、user/署名(`op-ssh-sign`)/ghq root/`init.defaultBranch` を移植する
- [ ] 4.3 `programs.tmux` を作成する
- [ ] 4.4 ghostty `config` を `mkOutOfStoreSymlink` でリポジトリ実体へリンクする
- [ ] 4.5 ssh の `config` / `config.d/` を out-of-store symlink で管理する（秘密鍵を含めない）
- [ ] 4.6 claude の statusline スクリプトを実行可能属性付きで配置する
- [ ] 4.7 各ファイルごとに `switch` して chezmoi 適用結果と `diff` で一致を確認する
- [ ] 4.8 dotfiles 移行分をコミットする

## 5. 撤去: chezmoi と Brewfile を削除しドキュメント更新

- [ ] 5.1 全 dotfile の一致確認が済んだことを最終確認する
- [ ] 5.2 out-of-store symlink 先の生ファイルを chezmoi プレフィックスを外した非 chezmoi パスへリネームする（`dot_config/ghostty/config` → `config/ghostty/config`、`private_dot_ssh/{config,config.d/}` → `ssh/{config,config.d/}`、`private_dot_claude/executable_statusline-command.sh` → `claude/statusline-command.sh`）
- [ ] 5.3 リネームした実行可能スクリプトに `chmod +x` を付与し、`home.nix` の symlink 先パスを新パスへ更新して `switch` で疎通確認する
- [ ] 5.4 native モジュール化済みの実体ファイルを削除する（`dot_zshrc` / `private_dot_gitconfig`）
- [ ] 5.5 `dot_Brewfile` / `.chezmoiignore` を削除し、Brewfile の `chezmoi` formula 撤去に伴い chezmoi をアンインストールする
- [ ] 5.6 `README.md` の新 PC セットアップ手順を Nix 版（Determinate インストール → `darwin-rebuild switch --flake .#<host>`）へ更新する
- [ ] 5.7 クリーン再現の手順（`--rollback` によるロールバック含む）を README に追記する
- [ ] 5.8 撤去とドキュメント更新分をコミットする
