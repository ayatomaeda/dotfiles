# Spec Delta

## ADDED Requirements

### Requirement: 対話 zsh の補完の dump は起動の仕方に依らず作り直されない

システムは、対話 zsh の補完の dump を、起動の仕方 (端末のアプリが起動したシェル、シェルから起動したシェル、
macOS の `/bin/zsh` と Nix の zsh のどちら) に依らず、構成が変わらない限り作り直させてはならない (MUST NOT)。

`compinit` は、dump の 1 行目の「fpath に見える補完ファイルの個数」と「zsh の版」が今のシェルと違えば dump を作り直す。
dump はこの 2 つを鍵にした cache なので、システムは鍵が起動の仕方で変わらない構成にしなければならない (SHALL)。

- 補完の初期化 (`compinit`) は、利用側が与える home-manager の構成が生成する `~/.zshrc` の 1 回だけで行わなければ
  ならない (SHALL)。core の darwin モジュールは、nix-darwin が全ユーザー向けの `/etc/zshrc` に置く `compinit` を
  止めなければならない (SHALL)。home-manager 側を止めて nix-darwin 側を残す形にしてはならない (MUST NOT)。
  home-manager の `compinit` は fpath の組み立ての後、`compdef` を使う初期化 (fzf、zoxide) の前に並び、nix-darwin の
  無い環境でも同じ `~/.zshrc` で動くため。
- fpath に補完を足す初期化 (Homebrew の `brew shellenv` を含む) は、`~/.zshrc` の中で、home-manager が fpath の重複を
  除く宣言 (`typeset -U`) より後、`compinit` より前に置かなければならない (SHALL)。前に置けば、親から受け継いだ
  fpath の重複が除かれ、`compinit` は自分の fpath の完成した形を数える。
- dump は zsh の版ごとに別のファイルにしなければならない (SHALL)。対話シェル (ログインシェル) と `PATH` の `zsh` が
  別の版である構成を、core は宣言で 1 つにそろえられない。

この要件の前提として、**home-manager を使わないアカウントの対話 zsh には、補完の初期化が無い。** core の darwin
モジュールは home-manager の darwin モジュールの読み込みをすでに前提にしているので新しい前提ではないが、
`README.md` の「利用側が与えるもの」に書かなければならない (SHALL)。

#### Scenario: 端末のアプリが起動したシェルとシェルから起動したシェルを混ぜる

- **WHEN** 端末のアプリが起動した `/bin/zsh`、そのシェルから起動した `/bin/zsh`、そのシェルから起動した Nix の zsh、
  Nix の zsh から起動した `/bin/zsh` を、この順で 2 回繰り返して起動する
- **THEN** 最初の 1 巡の後、どの dump のファイルの更新時刻も変わらない
- **AND** 1 つのシェルの起動時間が、端末のアプリが起動したシェルと同じ程度である

#### Scenario: 生成物の中の `compinit`

- **WHEN** switch した後に `/etc/zshrc` と `~/.zshrc` を読む
- **THEN** `compinit` の呼び出しは `~/.zshrc` に 1 つだけあり、`/etc/zshrc` には無い
- **AND** `~/.zshrc` の `brew shellenv` は、`typeset -U` の宣言より後、`compinit` の呼び出しより前にある
- **AND** `/etc/zshenv` が fpath に Nix のプロファイルを足す記述は残っている

#### Scenario: 補完が使える

- **WHEN** 端末のアプリが起動したシェルとそのシェルから起動したシェルで、補完の関数を引く
- **THEN** どちらのシェルでも、core が宣言したツールの補完 (`_rg`)、Homebrew の補完 (`_brew`)、zsh 同梱の補完 (`_git`)
  と `compdef` が関数として解決する
- **AND** 起動の標準エラー出力に、補完の初期化のエラーや警告が無い

#### Scenario: `/etc/zshrc` の `compinit` に頼らない

- **WHEN** nix-darwin の `/etc/zshrc` から `compinit` の行だけを除いた構成で、対話 zsh を起動する
- **THEN** 補完の初期化と、`compdef` を使う fzf と zoxide の初期化が、`~/.zshrc` だけでエラー無く通る

#### Scenario: 前提の記録

- **WHEN** 利用側が core の darwin モジュールを読み込む前に `README.md` の「利用側が与えるもの」を読む
- **THEN** 補完の初期化が home-manager の構成に頼っていることと、home-manager を使わないアカウントの対話 zsh には
  補完の初期化が無いことが書かれている
