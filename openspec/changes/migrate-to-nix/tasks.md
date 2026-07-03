## 0. 事前確定（解決済み）

- [x] 0.1 nixpkgs チャンネル = `nixpkgs-unstable` に確定（darwin の網羅性・鮮度重視。再現性は flake.lock で担保）
- [x] 0.2 対象アーキテクチャ = `aarch64-darwin`（Apple Silicon）に確定
- [x] 0.3 `appium` / `periphery` は nixpkgs 未提供を `nix search` で確認 → `homebrew.brews` に残すことに確定

## 1. 土台: Nix インストールと最小構成で switch を通す

> 注: 調査の結果、Determinate Nix 3.17.2 / flakes / nix-darwin は**既に導入済み**だった（過去に試して放置した最小構成。ユーザー承諾のうえ本 flake で置き換える）。よって 1.1 は導入不要。

- [x] 1.1 Nix 導入 — Determinate Nix 3.17.2 が導入済み（flakes 有効・nix-darwin 稼働中）を確認。新規インストール不要
- [x] 1.2 実ホスト名を確認する (`scutil --get LocalHostName`) → `KeisukenoMac-Studio`
- [x] 1.3 `flake.nix` を作成し、inputs に `nixpkgs`(→`nixpkgs-unstable`) / `nix-darwin` / `home-manager` を宣言、outputs に `darwinConfigurations.KeisukenoMac-Studio`（`nixpkgs.hostPlatform = "aarch64-darwin"`）を定義
- [x] 1.4 `darwin.nix` に最小のシステム構成を書き、`nix.enable = false;`（Determinate 競合回避）/ `system.primaryUser` / `stateVersion = 6` を設定
- [x] 1.5 `home.nix` に最小の home-manager 構成を書き、nix-darwin のモジュールとして組み込み。`darwin-rebuild build` で評価・ビルド成功を確認（非破壊）
- [x] 1.6 `sudo darwin-rebuild switch --flake .#KeisukenoMac-Studio` 成功を確認（activation・home-manager activation 完走、Determinate 競合なし）
- [x] 1.7 この時点の `flake.nix` / `flake.lock` / `darwin.nix` / `home.nix` / `.gitignore` をコミットする
- [x] 1.8 (インシデント対応) 旧 standalone HM が管理していた dotfiles が switch で削除された件を復旧: chezmoi ソースから再適用し、`.chezmoiignore` に flake/openspec を追加して `$HOME` 誤展開を防止（design Risks 参照）

## 2. CLI: formula を Nix ネイティブへ移行

- [x] 2.0 (暫定) brew が新シェル PATH から外れていた件 → CLI の nix 化で解消（node 含む主要ツールは nix プロファイル経由で PATH に復帰）
- [x] 2.1 各 CLI の nixpkgs 提供を `nix eval` で確認（git 2.54 / tmux 3.6a / nodejs 24.15 / ffmpeg 8.1 / gh 2.94 / ghq 1.10 / uv 0.11 / yt-dlp 2026.06 / swiftlint 0.63、すべて aarch64-darwin で解決）
- [x] 2.2 上記 9 ツールを `home.packages` で宣言（git/tmux は Phase 4 で `programs.*` へ移す予定）
- [ ] 2.3 `appium` / `periphery` を `homebrew.brews` に列挙する（Phase 3 で homebrew モジュール有効化と同時に実施）
- [ ] 2.3a `chezmoi` formula はこの Phase では Nix へ移さず既存 brew のまま残す（Phase 4 の一致確認に使うため。撤去は Phase 5）
- [x] 2.4 `switch` して各 CLI が `/etc/profiles/per-user/keisuke/bin/` に解決されることを確認。※brew 側の重複 formula のアンインストールは Phase 3 の homebrew 突合/Phase 5 撤去でまとめて実施（今は共存・無害）
- [x] 2.5 CLI 移行分をコミットする

## 3. GUI/mas: cask・Mac App Store を homebrew モジュールへ移行

- [ ] 3.1 `homebrew.enable = true;` を設定し、`homebrew.casks` に全 cask を列挙する
- [ ] 3.2 `homebrew.masApps` に全 Mac App Store アプリを名前と ID で列挙する（Keynote/Numbers/Pages/Xcode/Kindle/Spark）
- [ ] 3.3 `mas` CLI を `homebrew.brews` に残す
- [ ] 3.4 `homebrew.onActivation.cleanup = "check"`（非破壊）で `switch` し、未列挙アプリが無いことを確認する
- [ ] 3.5 全項目の列挙漏れが無いことを確認後、必要なら `cleanup` を `"uninstall"`/`"zap"` へ厳格化する
- [ ] 3.6 GUI/mas 移行分をコミットする

## 4. dotfiles: home-manager へ移行

- [ ] 4.0 既存の素ファイル (`~/.zshrc` 等) と HM の symlink 生成の衝突を避けるため `home-manager.backupFileExtension = "hm-bak";` を設定する（または対象ファイルを事前削除）。`programs.zsh` では brew shellenv も明示して PATH を恒久化する
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
- [ ] 5.5a 旧 standalone home-manager の残骸プロファイルを掃除する（`~/.local/state/nix/profiles/home-manager*` の旧世代。`nix profile` / world 削除で不要世代を除去し、GC）
- [ ] 5.6 `README.md` の新 PC セットアップ手順を Nix 版（Determinate インストール → `darwin-rebuild switch --flake .#<host>`）へ更新する
- [ ] 5.7 クリーン再現の手順（`--rollback` によるロールバック含む）を README に追記する
- [ ] 5.8 撤去とドキュメント更新分をコミットする
