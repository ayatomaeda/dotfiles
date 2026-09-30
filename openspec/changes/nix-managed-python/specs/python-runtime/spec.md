## ADDED Requirements

### Requirement: Python のインタープリタは Nix のパッケージとして宣言する

システムは、Python のインタープリタを nixpkgs のパッケージとして `home.packages` に宣言しなければならない (SHALL)。インタープリタの実体は Nix の store に置き、`flake.lock` で固定されなければならない (SHALL)。

activation の中でインタープリタや Python の CLI をネットワークから導入してはならない (MUST NOT)。したがって home-manager の `programs.uv.python.*` と `programs.uv.tool.*` を使ってはならない (MUST NOT)。これらは activation で `uv python install` / `uv tool install` を実行し、store の外に状態を作るため。

#### Scenario: switch 後のインタープリタの所在

- **WHEN** `switch` を実行する
- **THEN** `python3` と、宣言したマイナー版の `python3.<minor>` が、`/etc/profiles/per-user/<user>/bin` から解決される
- **AND** それぞれの実体は `/nix/store` にある

#### Scenario: activation がネットワークに出ない

- **WHEN** 版を変えずに、オフラインで `switch` を実行する
- **THEN** Python に関する activation の処理は無く、switch は成功する

### Requirement: 置く版は規則で決め、番号を書かない

システムは、nixpkgs の既定の `python3` と、その 1 つ前のマイナー版を宣言しなければならない (SHALL)。1 つ前の版は、既定の `python3` の版から評価のときに導出しなければならない (SHALL)。版の番号を宣言に直接書いてはならない (MUST NOT)。

共通の実行ファイル名 (`python3`・`python`・`pydoc3` など) は、既定の版を指さなければならない (SHALL)。

#### Scenario: nixpkgs が既定の版を上げたとき

- **WHEN** nixpkgs の既定の `python3` が次のマイナー版に上がった rev に lock を更新する
- **THEN** 宣言を書き換えずに、置かれる 2 つの版がそろって 1 つずつ上がる

#### Scenario: nixpkgs が 1 つ前の版を消したとき

- **WHEN** 導出した 1 つ前の版の属性が、pin した nixpkgs に存在しない
- **THEN** 構成の評価が失敗し、switch の前に検出される

#### Scenario: 共通の名前の解決

- **WHEN** 2 つの版を同じプロファイルに置く
- **THEN** buildEnv の衝突で失敗せず、`python3` は既定の版を指す
- **AND** 1 つ前の版は `python3.<minor>` の名前で使える

### Requirement: uv はインタープリタを入れず、Nix のものだけを使う

システムは、uv の設定として `python-downloads = "never"` と `python-preference = "only-system"` を宣言しなければならない (SHALL)。この設定は `programs.uv.settings` から生成する `uv.toml` に書かなければならない (SHALL)。`home.sessionVariables` などの環境変数で与えてはならない (MUST NOT)。

`UV_PYTHON` を設定してはならない (MUST NOT)。`uv pip install` が store の prefix を書き換え対象にするため。

`only-system` は Nix 以外の system Python (Homebrew の Python、macOS の `/usr/bin/python3`) も候補から外さない。uv には特定のパスを除外する設定が無い。したがってこの構成は、**宣言していない版を求めたときに Nix 以外の Python が選ばれることを防げない**。システムの文書は、この抜け穴と、`.python-version` には宣言した版だけを書くという約束を示さなければならない (SHALL)。

#### Scenario: どこにも無い版を求められたとき

- **WHEN** プロジェクトの `.python-version` が、宣言しておらず、PATH 上のどの system Python も持たない版を指している
- **THEN** uv はダウンロードせず、インタープリタが見つからないというエラーで止まる

#### Scenario: 宣言していないが Nix の外にある版を求められたとき

- **WHEN** プロジェクトの `.python-version` が、宣言していないが Homebrew または macOS が持つ版 (例: `/usr/bin/python3` の 3.9) を指している
- **THEN** uv はその Nix の外の Python を使い、エラーにならない
- **AND** これはこの構成が防がない既知の抜け穴であり、文書の約束で避ける

#### Scenario: uv が選ぶインタープリタ

- **WHEN** 宣言した版を `.python-version` に書いたプロジェクトで `uv python find` を実行する
- **THEN** 解決先は `/etc/profiles/per-user/<user>/bin` の下にある
- **AND** `~/.local/share/uv/python` の下ではない

#### Scenario: 既存のシェルとエージェントへの反映

- **WHEN** `switch` した後、起動し直していないシェル、または Claude Code の Bash で uv を実行する
- **THEN** 設定が `uv.toml` から読まれ、同じ振る舞いになる

#### Scenario: パッチ版の更新と venv

- **WHEN** lock の更新で、同じマイナー版のインタープリタの store パスが変わり (パッチ版の更新)、`switch` の後に GC を実行する
- **THEN** 既存の `.venv` は、プロファイルを経由して新しいパッチ版で動き続ける

#### Scenario: マイナー版が入れ替わるときの venv

- **WHEN** nixpkgs の既定の `python3` が上がり、置く 2 つの版が入れ替わる lock の更新を `switch` する
- **THEN** 置かれなくなった版を指す `.venv` は、そのマイナー版の実行ファイルがプロファイルから消えるので動かなくなる
- **AND** 汎用の名前 (`python3`) を指す `.venv` は、別のマイナー版に黙って切り替わり、site-packages と合わなくなる
- **AND** したがってマイナー版が入れ替わる更新の後は、影響を受ける `.venv` を作り直す (`uv sync`)。システムの文書はこの手順を示さなければならない (SHALL)

### Requirement: プロジェクトはマイナー版で選び、それ以外の版はプロジェクト側で渡す

プロジェクトの `.python-version` は、宣言した版をマイナー版の形 (`3.13`) で書く約束とする。システムの文書は、この約束を示さなければならない (SHALL)。宣言していない版が要るプロジェクトについては、そのプロジェクトの devShell でインタープリタを PATH に置く手順を示さなければならない (SHALL)。

Python の CLI は `uvx` で実行し、1 ファイルのスクリプトは PEP 723 の依存の宣言と `uv run --script` で実行する約束とする。システムの文書は、この約束を示さなければならない (SHALL)。

#### Scenario: 宣言していない版が要るプロジェクト

- **WHEN** あるプロジェクトが、宣言していないマイナー版を必要とする
- **THEN** そのプロジェクトの `flake.nix` の devShell がその版を PATH に置き、`direnv` + `nix-direnv` で読み込む
- **AND** このリポジトリの宣言には足さない

#### Scenario: 非対話のエージェントでの実行

- **WHEN** Claude Code の Bash で、devShell を持つプロジェクトの uv を実行する
- **THEN** `direnv exec . uv …` と明示して実行する

### Requirement: uv の管理する Python の撤去は、一覧を示して承認を得てから行う

システムは、uv の管理する Python (`~/.local/share/uv/python`) を撤去する前に、撤去する版と、それを指している `.venv` の一覧を非破壊で示さなければならない (SHALL)。所有者の承認を得るまで撤去してはならない (MUST NOT)。

#### Scenario: 移行のときの撤去

- **WHEN** この構成を初めて適用し、uv の管理する Python が残っている
- **THEN** `uv python list --only-installed --managed-python` の結果と、影響を受ける `.venv` の一覧を示す
- **AND** 承認の後に `uv python uninstall` で撤去し、各プロジェクトで `uv sync` を実行して、`.venv` が作り直されることを確かめる
