# package-management Specification

## Purpose
CLI ツール、GUI アプリ、Mac App Store アプリの宣言のしかた。Nix で扱えるものは Nix で、扱えないものは nix-darwin の homebrew モジュールで宣言し、削除を伴う変更は適用の前に確かめる。

## Requirements
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
- **AND** 確認は `nix search` ではなく **`flake.lock` が pin している rev に対する評価**で行う (`nix search nixpkgs` は Determinate Nix の `extra-nix-path` により FlakeHub の nixpkgs-weekly を参照するため、pin と一致しない)

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

### Requirement: プロジェクト固有のツールチェーンをグローバルに置かない

システムは、特定のプロジェクトでのみ使用するツールチェーンを、グローバルなパッケージ宣言 (`home.packages` / `homebrew.brews`) に置いてはならない (MUST NOT)。利用するプロジェクト側で宣言する。宣言の手段は次のいずれかを用いる。

- そのツールのエコシステム固有の依存解決機構 (npm の devDependency 等)
- プロジェクトの `flake.nix` が定義する devShell を `direnv` + `nix-direnv` で読み込む

後者は、エコシステム固有の機構を持たないツール (`opentofu` 等) や、ランタイムそのものの版をプロジェクト単位で固定したい場合に用いる。

#### Scenario: npm パッケージであるツールの扱い

- **WHEN** あるツールが npm パッケージとして配布されており、特定プロジェクトでのみ使用される
- **THEN** そのプロジェクトの `package.json` に devDependency として宣言し、`npx` 経由で実行する
- **AND** グローバルの `homebrew.brews` / `home.packages` には宣言しない

#### Scenario: グローバル宣言の除去による副次的負債の解消

- **WHEN** グローバル宣言されていたツールが、その依存として別のランタイム (例: Homebrew の `node`) を持ち込んでいた
- **THEN** そのツールの除去後、ランタイムの優先順位を調整するための回避策 (PATH 順の操作等) を削除する

#### Scenario: エコシステム固有の機構を持たないツールの扱い

- **WHEN** あるツールが特定プロジェクトでのみ使用され、かつ npm のような依存解決機構を持たない
- **THEN** そのプロジェクトの `flake.nix` の devShell に宣言し、`.envrc` から読み込む
- **AND** dotfiles リポジトリは `direnv` + `nix-direnv` を使える状態にするところまでを担当する

### Requirement: 破壊的な cleanup は適用前に一覧を提示する

システムは、`homebrew.onActivation.cleanup` により宣言外のパッケージが除去される構成において、宣言を削減する変更を適用する前に、**削除対象の一覧を非破壊的に提示**しなければならない (SHALL)。所有者の承認を得るまで適用してはならない (MUST NOT)。

#### Scenario: 宣言削減時の事前確認

- **WHEN** `homebrew.brews` からエントリを削除する変更を行う
- **THEN** `switch` の前に dry-run で削除対象の formula 一覧を提示する
- **AND** 一覧に想定外のものが含まれる場合は、Nix 側へ引き取るか `homebrew.brews` に明示してから適用する

### Requirement: 非公式 tap は信頼を明示して宣言する

システムは、Homebrew の非公式 (サードパーティ) tap を宣言する場合、**その tap を信頼することを明示**しなければならない (SHALL)。Homebrew 6.0.0 以降は信頼していない非公式 tap の formula / cask が読み込まれず、cask は**黙ってスキップされる**ため。

#### Scenario: 非公式 tap からの cask 導入

- **WHEN** 非公式 tap が配布する cask を宣言する
- **THEN** その tap を `trusted` を付けて宣言する
- **AND** 生成される Brewfile の tap 行に `trusted: true` が含まれる

#### Scenario: 既存環境では症状が出ない壊れ方

- **WHEN** 対象の cask が既に導入済みである
- **THEN** `brew bundle` は充足済みとして扱い、警告以外の症状が出ない
- **AND** したがって**クリーンな環境で導入されるかどうかを基準に**判断しなければならない

#### Scenario: cask 側の信頼指定では解決しない

- **WHEN** 非公式 tap の cask を fully-qualified でない素の名前 (`<cask>` のみ) で宣言している
- **THEN** cask 側の信頼指定は効かず、tap 側の信頼が必要である

### Requirement: 利用されなくなったパッケージ宣言を残さない

システムは、宣言しているパッケージが**実際に利用されている**状態を保たなければならない (SHALL)。利用がなくなったパッケージの宣言を残してはならない (MUST NOT)。

利用の有無は、そのツールの対象となる成果物が対象ホスト上に存在するかで判定する。判定は**対象ホストすべてに対して**行う。`modules/common/` の宣言は全ホストへ配布されるため、1 台で利用が確認できないことは撤去の根拠にならない。

宣言を撤去するときは、**同じ前提に立っている他の宣言・コメント・文書も同時に更新**しなければならない (SHALL)。パッケージ宣言は単独では存在せず、導入経緯を説明するコメント、README の記述、関連するエディタ/エージェントのプラグイン設定と結びついている。

#### Scenario: 利用実態の確認

- **WHEN** あるパッケージの撤去を検討する
- **THEN** そのツールが対象とする成果物 (Swift なら `*.xcodeproj` / `Package.swift` 等) を対象ホスト上で探索する
- **AND** 探索範囲と結果を記録する
- **AND** 所有者に利用の有無を確認する

#### Scenario: 撤去に伴う波及の処理

- **WHEN** パッケージ宣言を撤去する
- **THEN** そのパッケージに言及しているコメント・`README.md` の記述を更新する
- **AND** 同じ前提に立っている他の設定 (エージェントのプラグイン等) も同時に見直す

#### Scenario: Homebrew 側の宣言を伴う場合

- **WHEN** 撤去対象が `homebrew.*` の宣言を含む
- **THEN** 既存要求「破壊的な cleanup は適用前に一覧を提示する」に従い、削除対象の一覧提示と承認を先に行う
- **AND** 再取得のコストが高いもの (Mac App Store の大型アプリ等) は、Nix 側の撤去とは別の変更として扱う

