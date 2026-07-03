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

- [x] 3.1 `homebrew.enable = true;` + `homebrew.casks` に cask を列挙（`claude-code` は除外＝自動更新される native インストーラで管理）
- [x] 3.2 `homebrew.masApps` に全 mas アプリを列挙（Keynote/Numbers/Pages/Xcode/Kindle/Spark）
- [x] 3.3 `mas` CLI を `homebrew.brews` に残す（＋ chezmoi / periphery / appium）
- [x] 3.4 `onActivation.cleanup = "none"`（"check" より安全な非破壊）で `switch`。`brew bundle complete!` 全 30 項目 "Using" を確認
- [x] 3.4a `appium` を npm グローバル → brew formula へ移行（npm 版削除 → `brew link --overwrite appium`）
- [x] 3.4b Homebrew 本体を 5.1.4 → 6.0.6 へ更新（1password-cli cask の新 DSL に旧 brew が非対応だったため。`brew update`）
- [ ] 3.5 `cleanup` を `"uninstall"` へ厳格化（★別ステップ）。事前に: (a) 宣言外の brew cask `amazon-photos` / `cmux` / `logitech-options` を config 追加 or 除外決定、(b) nix へ移行した 9 formula の brew 重複・appium の孤立依存(gcc 等)が削除対象になる点を確認・提示してから実施
- [x] 3.6 GUI/mas 移行分をコミットする

## 4. dotfiles: home-manager へ移行

- [x] 4.0 `home-manager.backupFileExtension = "hm-bak"` を flake.nix に設定（衝突時 `.hm-bak` 退避）。`programs.zsh.initContent` に brew shellenv を明示
- [x] 4.1 `programs.zsh` に alias・history・カスタム ssh 関数・PROMPT・zstyle・`PATH` を移植（既存 .zshrc は `.zshrc.hm-bak` に退避）
- [x] 4.2 `programs.git`（`settings` 形式）に user/署名(`op-ssh-sign`)/ghq root/`init.defaultBranch` を移植。旧 `~/.gitconfig` を除去し HM の `~/.config/git/config` を単独ソース化。署名設定の実効値を検証済み
- [x] 4.3 `programs.tmux.enable`（既存 tmux 設定ファイルは無いため最小）
- [x] 4.4 ghostty `config` を `mkOutOfStoreSymlink` でリンク（実体到達を検証済み）
- [x] 4.5 ssh の `config` / `config.d/` を out-of-store symlink 化（秘密鍵は対象外・無事）
- [x] 4.6 claude statusline スクリプトを symlink 配置（実行可能属性は実体側で保持）
- [x] 4.7 switch 後に検証: 5 ファイルの symlink 実体到達 / .zshrc 主要要素の移植 / git identity・署名の実効値をすべて確認
- [x] 4.8 dotfiles 移行分をコミットする（＋事後: node PATH を nix 優先へ修正）

## 5. 撤去: chezmoi と Brewfile を削除しドキュメント更新

- [x] 5.1 全 dotfile が HM 管理へ移行済み（symlink 実体到達・git 署名・zsh 移植を検証）
- [x] 5.2 out-of-store symlink 先を非 chezmoi パスへリネーム（`config/ghostty/config`、`ssh/{config,config.d/}`、`claude/statusline-command.sh`）＋ home.nix 追従
- [x] 5.3 `claude/statusline-command.sh` に `chmod +x`、home.nix の symlink 先を新パスへ更新し switch で疎通確認
- [x] 5.4 native 化した実体ファイルを削除（`dot_zshrc` / `private_dot_gitconfig`）＋ 旧 `~/.gitconfig` も除去済み
- [x] 5.5 `dot_Brewfile` / `.chezmoiignore` を削除、`chezmoi` formula 撤去＋アンインストール完了
- [x] 5.5b (cleanup 厳格化) `cleanup="uninstall"` へ。dry-run で削除リストを提示し承認取得後、制御しながら削除: 宣言外 cask `amazon-photos`/`logitech-options`、実在ツール `oci-cli`/`supabase`(＋依存・tap) を除去。`cmux` は宣言下に追加＋ `homebrew.taps` に `manaflow-ai/cmux` を宣言（untap 拒否エラー回避）。cmux/appium 生存を確認
- [ ] 5.5a (任意・保留) 旧 standalone home-manager の残骸プロファイル (`~/.local/state/nix/profiles/home-manager*`) の掃除。無害な未使用世代のため後日 GC で可
- [x] 5.6 `README.md` を Nix 版（Determinate → `darwin-rebuild switch`、構成・日常運用）へ全面更新
- [x] 5.7 ロールバック（`--rollback`）とクリーン再現手順を README に追記
- [x] 5.8 撤去・cleanup・ドキュメント更新分をコミットする
