## ADDED Requirements

### Requirement: dotfiles は home-manager で宣言的に管理する

システムは、ユーザーの dotfiles を home-manager を通じて宣言的に管理しなければならない (SHALL)。移行完了後、chezmoi と `dot_*` / `private_dot_*` ファイルを情報源として使用してはならない (MUST NOT)。

#### Scenario: switch による dotfiles 配置

- **WHEN** `darwin-rebuild switch` を実行する
- **THEN** home-manager が管理する dotfiles がホームディレクトリに配置される

### Requirement: 主要設定は native モジュールで表現する

システムは、zsh・git・tmux の設定を home-manager の `programs.*` native モジュール (`programs.zsh` / `programs.git` / `programs.tmux`) で表現しなければならない (SHALL)。既存の挙動 (zsh の alias・history 設定・ssh 関数、git の 1Password `op-ssh-sign` 署名設定、ghq root など) を保持しなければならない (SHALL)。

#### Scenario: zsh 設定の移植

- **WHEN** `programs.zsh` で alias・history オプション・カスタム ssh 関数を宣言して `switch` する
- **THEN** 生成された `.zshrc` が既存の挙動を再現する

#### Scenario: git 署名設定の保持

- **WHEN** `programs.git` で 1Password の `op-ssh-sign` を用いた SSH 署名を宣言する
- **THEN** 生成された `.gitconfig` で従来どおり署名付きコミットが可能である

### Requirement: 頻繁に編集する生ファイルは out-of-store symlink にする

システムは、アプリ固有形式または頻繁に編集する生ファイル (ghostty の `config`、ssh の `config`/`config.d/`、claude の statusline スクリプト) を `config.lib.file.mkOutOfStoreSymlink` によりリポジトリ実体へシンボリックリンクしなければならない (SHALL)。

#### Scenario: 編集の即時反映

- **WHEN** out-of-store symlink 対象のファイルをリポジトリ上で編集する
- **THEN** rebuild なしに変更が有効な設定へ反映される

#### Scenario: 実行可能スクリプトの配置

- **WHEN** claude の statusline スクリプトを配置する
- **THEN** 実行可能属性を保ったままリンクされ、そのまま実行できる

### Requirement: 秘密情報を Nix store に置かない

システムは、秘密鍵・トークン等の秘密情報を Nix store (world-readable) に配置してはならない (MUST NOT)。SSH の `config`/`config.d/` は秘密鍵を含まず署名を 1Password に委譲しているため、home-manager で管理してよい (MAY)。

#### Scenario: SSH 設定の安全な管理

- **WHEN** ssh の `config`/`config.d/` を home-manager で管理する
- **THEN** 秘密鍵は含まれず、署名は 1Password の `op-ssh-sign` に委譲されたままである

### Requirement: chezmoi との一致確認後に撤去する

システムは、各 dotfile を home-manager へ移行した際、chezmoi 適用結果との一致を確認してから chezmoi 側の情報源を撤去しなければならない (SHALL)。

#### Scenario: 移行差分の検証

- **WHEN** ある dotfile を home-manager 化して `switch` する
- **THEN** 適用結果が従来の chezmoi 適用結果と一致することを確認できてから、対応する `dot_*` / `private_dot_*` ファイルを削除する
