## Context

現状は macOS 環境を 2 系統で管理している:

- **パッケージ**: `dot_Brewfile` (Homebrew) — formula (CLI) 13 個 + cask (GUI) 21 個 + mas (App Store) 6 個。
- **dotfiles**: chezmoi (`dot_zshrc`, `private_dot_gitconfig`, `private_dot_ssh/`, `private_dot_claude/`, `dot_config/ghostty/config`)。

バージョンがロックされず再現性が無い。所有者は Nix 未経験のため、学習しながら段階的に移行したい。

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

## Migration Plan

段階移行 (proposal / tasks.md の 5 ステップ)。各ステップ末尾で `darwin-rebuild switch` → 動作確認 → git コミット。ロールバックは直前コミットへ戻すか、nix-darwin の世代ロールバック (`darwin-rebuild --rollback`) で行う。chezmoi と `dot_*` の撤去は全 dotfiles の home-manager 移行と一致確認が済んだ最終ステップでのみ実施する。

## Open Questions

- nixpkgs チャンネルは stable (`nixos-25.11`) と `nixpkgs-unstable` のどちらを既定にするか。darwin は unstable 利用も一般的だが、初心者の安定性重視なら stable。→ 実装開始時に確定（暫定: unstable 寄り、要相談）。
- `appium` / `periphery` の nixpkgs 提供有無 → Step 2 の存在確認で確定。
- 将来 `nix.*` 設定を増やす必要が出た時点で determinateNix モジュールへ移行するか（現状は `nix.enable = false` で開始）。
