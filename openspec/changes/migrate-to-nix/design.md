## Context

現状は macOS 環境を 2 系統で管理している:

- **パッケージ**: `dot_Brewfile` (Homebrew) — formula (CLI) 13 個 + cask (GUI) 21 個 + mas (App Store) 6 個。
- **dotfiles**: chezmoi (`dot_zshrc`, `private_dot_gitconfig`, `private_dot_ssh/`, `private_dot_claude/`, `dot_config/ghostty/config`)。

バージョンがロックされず再現性が無い。所有者は Nix 未経験のため、学習しながら段階的に移行したい。

> **実装時に判明した前提の訂正 (2026-07-03)**: 当初「Nix 未導入」と想定していたが、実機には **Determinate Nix 3.17.2 + nix-darwin + standalone home-manager (世代1) が既に存在**していた（所有者が過去に試して「放置」したつもりのもの）。この旧 standalone HM は dotfiles を **symlink で管理していた**。所有者合意のうえ本 flake で置き換える方針だが、Phase 1 の switch でこの旧 HM が管理していた dotfiles リンク (`~/.zshrc` 等) が「孤立リンク」として削除される事象が発生した（詳細と対策は Risks 参照）。したがって Phase 1 の「Nix 導入」は不要で、実質「既存の放置構成を本 flake へ置換する」作業だった。

macOS 固有の制約: nixpkgs は CLI ツールには強いが、GUI アプリ (cask) と Mac App Store アプリは Nix ネイティブでは扱えない。nix-darwin の設計上、cask/mas は Homebrew に委譲する。したがって「Homebrew の完全撤去」は非現実的で、ゴールは **Nix を司令塔にし、Homebrew を裏方として宣言的に駆動する** 構成となる。

Web / context7 で 2026 年時点のベストプラクティスを検証済み (flakes + nix-darwin + home-manager モジュール構成 / `homebrew.*` + `onActivation.cleanup` / Determinate installer / out-of-store symlink)。詳細は proposal と各 spec を参照。

## Goals / Non-Goals

**Goals:**
- 単一の `flake.nix` から CLI・GUI・dotfiles を宣言的に管理し、`flake.lock` で再現性を保証する。
- `darwin-rebuild switch --flake .#<host>` 一発で system と home を同時適用できる。
- 段階移行により、各ステップで動作確認・ロールバック・コミットできる。
- 所有者が Nix の基本 (flake / nix-darwin / home-manager / homebrew モジュール) を学べる構成にする。

**Non-Goals:**
- Homebrew 本体の完全撤去（cask/mas 用に残す）。
- nix-homebrew による Homebrew インストール自体の宣言化（将来の拡張余地として残す）。
- NixOS / Linux 対応、`nix develop` によるプロジェクト別開発シェル。
- 既存 CLI 全ツールの `programs.*` 完全モジュール化（native モジュールは zsh/git/tmux に限定し、他は `home.packages` に列挙）。

## Decisions

### Decision 1: flakes を入口にする（channels ではなく）
- **理由**: `flake.lock` による入力の厳密なピン留めで再現性が得られる。ロールバックが容易。2026 年の事実上の標準。
- **代替案**: 従来の channels — 再現性が弱く、初心者向け教材も flakes へ移行済みのため不採用。

### Decision 2: home-manager を nix-darwin の「モジュール」として組み込む（standalone にしない）
- **理由**: `darwin-rebuild switch` 一発で system と home を同時に適用でき、単一リポジトリ・単一コマンドで完結する。所有者の「一元管理したい」目的に一致。
- **代替案**: standalone home-manager — system と home を別コマンドで更新でき独立性は高いが、管理点が増え初心者には複雑。不採用。

### Decision 3: cask/mas は nix-darwin の `homebrew.*` モジュールで宣言的に管理する
- **理由**: GUI/mas は Nix ネイティブでは扱えないため。`homebrew.enable = true` で Brewfile 相当を Nix 側に宣言でき、実体は brew bundle が導入する。`mas` CLI は masApps 導入に必要なので `homebrew.brews` に残す。
- **掃除**: `homebrew.onActivation.cleanup` を最初は `"uninstall"`(または検証用に一時的に `"check"`) にし、移行安定後に必要なら `"zap"` にする。いきなり `"zap"` にすると未列挙アプリの設定ごと消える事故があるため段階的に厳格化する。

### Decision 4: インストーラは Determinate Systems 製 + Nix 管理の境界を明示する ⚠️
- **理由**: 2026 年時点で macOS の推奨インストーラ。macOS アップグレードで壊れにくい。
- **競合と解決**: Determinate Nix は Nix 本体/設定を自前で管理するため、nix-darwin の `nix.*` 管理と衝突する。解決は 2 択:
  - **採用**: nix-darwin で `nix.enable = false;` にし、Nix 本体の管理は Determinate に委ねる（`nix.*` によるカスタム設定は `/etc/nix/nix.custom.conf` 側で行う）。初心者にはこちらが素直で情報も多い。
  - **代替**: nix-darwin の `determinateNix.enable = true;` + `determinateNix.customSettings` を使う（`nix.enable = false` 不要で `nix.*` 相当をカスタムできる）。より新しい方式。将来 `nix.*` 設定を増やしたくなったらこちらへ移行する。
- 本移行では **`nix.enable = false;` から開始**し、必要が生じたら determinateNix モジュールへ移行する。

### Decision 5: dotfiles は native モジュールと out-of-store symlink を使い分ける
- **native モジュール** (`programs.zsh` / `programs.git` / `programs.tmux`): 設定を Nix で表現し、Nix の書き味を学べる。zsh の alias / history / ssh 関数は `programs.zsh.initExtra` 等へ、git の 1Password 署名 (`op-ssh-sign`) 設定はそのまま移植する。
- **out-of-store symlink** (`config.lib.file.mkOutOfStoreSymlink`): ghostty の `config`、ssh の `config`/`config.d/`、claude の statusline スクリプトなど、アプリ固有形式または頻繁に編集する生ファイルはリポジトリ実体へ直接シンボリックリンクする。これにより編集後の rebuild 不要で即反映できる。
- **リポジトリ実体の扱い**: out-of-store symlink は「リポジトリ内に実体が残るファイル」を指す。chezmoi 撤去後もこれらは削除せず、chezmoi プレフィックス (`dot_` / `private_` / `executable_`) を外した非 chezmoi パス（例: `config/ghostty/config`, `ssh/config`, `claude/statusline-command.sh`）へリネームして残す。`executable_` プレフィックスが無くなる分、実行可能スクリプトはリポジトリ側の実体に `+x`（`chmod +x`）を付与しておく必要がある（symlink はリンク先のパーミッションをそのまま反映するため）。
- **理由**: `home.file` の既定は Nix store への読み取り専用コピーで、編集のたびに rebuild が要る。頻繁編集ファイルには out-of-store symlink が定石。

### Decision 6: リポジトリ構成は最小 2 ファイルから始める
- 初期: `flake.nix` + `darwin.nix` + `home.nix`。慣れてきたら `home/git.nix` のように分割する。
- **理由**: 初心者の認知負荷を下げ、最初の `switch` 成功体験を早める。

### Decision 7: 秘密情報は Nix store に置かない
- SSH の `config`/`config.d/` は秘密鍵を含まず、署名は 1Password の `op-ssh-sign` に委譲済みのため安全に home-manager で管理できる。
- 秘密鍵・トークン類は今後も Nix store（world-readable）へ入れない。必要が生じたら sops-nix 等を別途検討（本移行では対象外）。

## Risks / Trade-offs

- **[Determinate Nix と nix-darwin の競合で activation が失敗する]** → Decision 4 の通り `nix.enable = false;` を最初から設定する。`error: Determinate detected, aborting activation` が出たらこの設定漏れを疑う。
- **[`onActivation.cleanup = "zap"` で未列挙アプリが設定ごと消える]** → 初期は `"uninstall"`/`"check"` で挙動を確認し、全 cask/mas を漏れなく列挙できたことを確認してから厳格化する。
- **[nixpkgs に無い CLI (`appium` `periphery` 等) を Nix ネイティブ化できない]** → 存在確認 (`nix search`) の上、無ければ `homebrew.brews` に残す。全 CLI の Nix 化に固執しない (Non-Goal)。
- **[dotfiles 移行で chezmoi 版と差分が出て挙動が変わる]** → 各ファイルごとに移行後 `switch` して、chezmoi 適用結果と `diff` で一致確認してから chezmoi 側を削除する。
- **[学習コストによる中断]** → 段階移行で各ステップ完了時にコミットし、いつでも中断・再開・ロールバックできる状態を保つ。
- **[ホスト名の不一致で `--flake .#<host>` が解決できない]** → `scutil --get LocalHostName` で確認した実ホスト名を `darwinConfigurations` のキーに使う（または固定名にして `--flake .#default` を使う）。
- **[既存の standalone home-manager が管理していた dotfiles が switch で削除される]** ⚠️ 実際に発生。旧 standalone HM が `~/.zshrc` 等を symlink 管理していたため、本 flake（Phase 1 は dotfiles 非管理）へ switch した際に HM が孤立リンクとして削除した。→ **対策**: (1) 移行前に `ls ~/.local/state/nix/profiles/home-manager*` 等で既存 HM の有無と管理対象を確認する。(2) 削除された場合も chezmoi ソース (`private_dot_*`) が無傷なら復旧可能。復旧は chezmoi を使うが、**このリポジトリは chezmoi ソースと flake/openspec が同居する**ため、`.chezmoiignore` で非 dotfiles (flake.nix / openspec 等) を除外しないと `$HOME` に誤展開される（本 change で対応済み）。SSH 秘密鍵は HM 管理外なので影響しない。
- **[chezmoi 管理の素ファイルと home-manager の symlink 生成が衝突する (Phase 4)]** → Phase 4 で `programs.zsh` 等が `~/.zshrc` を生成する際、既存の素ファイルがあると activation が失敗する。→ **対策**: `home-manager.backupFileExtension = "hm-bak";` を設定して既存ファイルを退避させるか、移行対象ファイルを事前に削除してから switch する。
- **[brew が新シェルの PATH から外れる]** → 旧 HM が通していた brew の PATH が switch で失われた。応急は `eval "$(/opt/homebrew/bin/brew shellenv)"`。恒久対応は Phase 2 (CLI を nix 化＝nix プロファイルが `/etc/zshenv` 経由で PATH に乗る) と Phase 4 (`programs.zsh` で brew shellenv を明示) で解消する。

## Migration Plan

段階移行 (proposal / tasks.md の 5 ステップ)。各ステップ末尾で `darwin-rebuild switch` → 動作確認 → git コミット。ロールバックは直前コミットへ戻すか、nix-darwin の世代ロールバック (`darwin-rebuild --rollback`) で行う。chezmoi と `dot_*` の撤去は全 dotfiles の home-manager 移行と一致確認が済んだ最終ステップでのみ実施する。

## Resolved Decisions（旧 Open Questions）

- **nixpkgs チャンネル = `nixpkgs-unstable`（確定）**。再現性は `flake.lock` のピン留めで担保されるためチャンネル差は「更新頻度と鮮度」のみで、`nix flake update` を実行するまでバージョンは動かず、更新が気に入らなければ `flake.lock` を git で戻すだけでロールバックできる（構造上「勝手に壊れる」ことはない）。darwin はパッケージ網羅性・バイナリキャッシュの鮮度が unstable の方が良く、`yt-dlp`（YouTube 仕様変更で頻繁に破損＝鮮度が命）/`uv`/`node`/`gh` など鮮度が効くツールを含むため unstable を採用。将来「更新時の変化を最小化したい」なら現行 stable の `nixos-26.05` ベースへ、または「stable ベース＋ overlay で一部のみ unstable 混在」へ後から移行可能。
- **`appium` / `periphery` = Homebrew に残す（確定）**。`nix search nixpkgs` で確認した結果、両者とも nixpkgs に無い（`periphery` は無関係な `python-periphery`/`c-periphery` のみ、`appium` はサーバ本体ではなく `appium-inspector`/`appium-python-client` のみ）。したがって `homebrew.brews` に列挙する。
- **対象アーキテクチャ = `aarch64-darwin`（Apple Silicon）**。x86_64-darwin の非推奨 (Nixpkgs 26.05 で最後) の影響を受けない。

## Open Questions

- 将来 `nix.*` 設定を増やす必要が出た時点で determinateNix モジュールへ移行するか（現状は `nix.enable = false` で開始）。
