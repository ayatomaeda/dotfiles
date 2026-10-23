# Spec Delta

## ADDED Requirements

### Requirement: 対話 zsh の補完の初期化は home-manager の 1 回だけで行う

システムは、対話 zsh の補完の初期化 (`compinit`) を、利用側が与える home-manager の構成が生成する `~/.zshrc` の
1 回だけで行わなければならない (SHALL)。core の darwin モジュールは、nix-darwin が全ユーザー向けの `/etc/zshrc` に置く
`compinit` を止めなければならない (SHALL)。nix-darwin 側の `compinit` を残して home-manager 側を止める形にしてはならない
(MUST NOT)。

`compinit` は、`fpath` に見える補完ファイルの個数で `~/.zcompdump` の妥当性を判定する。別々の `fpath` で 2 回走ると、
個数が食い違ったときに互いに dump を無効にし合い、起動のたびに dump を 2 回作り直す。所有者の端末では、シェルから
起動したシェル (マルチプレクサのペイン、エージェントのシェル) がこの条件に当たり、起動に 1 秒以上かかっていた
(`/etc/zshrc` の `compinit` を飛ばすと 0.2 秒を下回り、dump の書き換えも止まった)。

home-manager 側を残すのは、その `compinit` が `fpath` の整理の後、`compdef` を使う初期化 (fzf、zoxide) の前に並び、
nix-darwin の無い環境 (standalone の home-manager) でも同じ `~/.zshrc` で動くため。nix-darwin 側に寄せると、
`modules/common` の補完が darwin 専用のファイルに依存し、`~/.zshrc` の中で `fpath` に足したものが dump に入らなくなる。

この要件の前提として、**home-manager を使わないアカウントの対話 zsh には、補完の初期化が無い。** core の darwin
モジュールは home-manager の darwin モジュールの読み込みをすでに前提にしているので、新しい前提ではないが、
`README.md` の「利用側が与えるもの」に書く。

#### Scenario: シェルから起動したシェル

- **WHEN** 対話 zsh から対話 zsh を続けて 2 回起動する (マルチプレクサのペインを開く、エージェントのシェル、`zsh` と打つ)
- **THEN** 2 回目の起動の前後で `~/.zcompdump` の更新時刻が変わらない
- **AND** そのシェルで core が宣言したツールの補完関数 (`_rg` など) が解決し、`compdef` が無いというエラーが出ていない

#### Scenario: 生成物の中の `compinit`

- **WHEN** switch した後に `/etc/zshrc` と `~/.zshrc` を読む
- **THEN** `compinit` の呼び出しは `~/.zshrc` に 1 つだけあり、`/etc/zshrc` には無い
- **AND** `/etc/zshenv` が `fpath` に Nix のプロファイルを足す記述は残っている

#### Scenario: nix-darwin の `/etc/zshrc` が無い環境

- **WHEN** `/etc/zshrc` を読まずに `~/.zshrc` だけで対話 zsh を起動する (`NOSYSZSHRC=1`。standalone の home-manager の形)
- **THEN** 補完の初期化と、`compdef` を使う fzf と zoxide の初期化がエラー無く通る

#### Scenario: 前提の記録

- **WHEN** 利用側が core の darwin モジュールを読み込む前に `README.md` の「利用側が与えるもの」を読む
- **THEN** 補完の初期化が home-manager の構成に頼っていることと、home-manager を使わないアカウントの対話 zsh には
  補完の初期化が無いことが書かれている
