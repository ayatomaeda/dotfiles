## Context

現状 (2026-09-30 の実測):

- 宣言は `modules/common/packages.nix` の `uv` の 1 行だけ。`~/.config/uv/uv.toml` も `UV_*` 変数も無い。
- 所有者の手元の uv のプロジェクトは、`.venv` が uv の管理する Python
  (`~/.local/share/uv/python/cpython-3.13.9-…`、`cpython-3.14.2-…`) をパッチ版のパスで直接指している。
  どちらも uv 0.9 系が入れたもので、マイナー版のリンク (`cpython-3.13-…`) を持たない。
- `python3` は PATH 上で `/opt/homebrew/bin/python3` に解決される。これは利用側が宣言した
  Homebrew の formula の依存として入ったもので、直接の宣言ではない。その次は `/usr/bin/python3` (3.9.6)。
- `uv python list` は、Homebrew の Python と `/usr/bin/python3` も「system」の候補として数えている。

各ドキュメントの記述 (探索の段階で調べた):

- Python (PEP 668、docs.python.org): ベースの Python は外 (distro、Nixpkgs、Homebrew) が管理する。
  依存は使い捨ての venv に置く。CLI はツールごとに隔離する。1 ファイルのスクリプトは PEP 723 で書く。
  `/usr/bin/python3` は Apple の開発ツール用なので当てにしない。
- uv: CLI は "In most cases, executing a tool with `uvx` is more appropriate than installing the tool"。
  Nix への言及は無い。
- nixpkgs の manual (`doc/packages/uv.section.md`): nixpkgs の Python を uv に渡し、`UV_PYTHON_DOWNLOADS=never`
  にすることを第一の選択肢としている。理由は NixOS で汎用 Linux のバイナリが動かないことで、macOS には
  この理由は当てはまらない。ここで同じ形を採る理由は、store・lock・GC に乗ること。
- pyproject.nix / uv2nix: Nix で配布しないなら uv2nix は要らない (impure テンプレート)。プロジェクトの配布は
  Docker で、Nix ではない。
- 個人の dotfiles の多数と devenv の既定: nixpkgs の Python に、`python-downloads = "never"` と
  `python-preference = "only-system"` を組み合わせている。

## Goals / Non-Goals

**Goals:**

- インタープリタを Nix の store に置き、`flake.lock` で固定し、GC で掃除され、評価の段階で壊れたことが
  分かるようにする。
- uv がインタープリタを入れない / 使わない状態を、宣言から生成した設定で保証する。
- 置く版を、番号ではなく規則で決め、lock の更新だけで追随させる。
- 人間とエージェント (Claude Code の Bash) が同じ Python を使う。

**Non-Goals:**

- プロジェクトの依存の管理を変えること (`uv.lock` のまま)。uv2nix は採らない。
- 各プロジェクトの `.python-version` や devShell を書き換えること (それぞれのリポジトリの仕事)。
- CLI を宣言して入れること (`uvx` で使う)。
- uv のキャッシュ (`~/.cache/uv`) の掃除を自動化すること。
- Homebrew の Python を消すこと (利用側の formula の依存なので、このリポジトリの管轄外)。

## Decisions

### D1. インタープリタは nixpkgs のパッケージにする

退けた案:

| 案 | 退けた理由 |
|---|---|
| home-manager の `programs.uv.python.versions` | activation で `uv python install` を実行し、ネットワークに出る。実体は store の外にあり、GC にも評価にも乗らない。2026-06 に入ったばかりで採用例がほとんど無い。home-manager は過去に、activation でネットワークに出る処理を「速く冪等であるべき」として撤去させている (tealdeer の前例)。`--default` は uv の experimental 機能で、`UV_PYTHON_PREFERENCE` を環境変数で与えると prune の計算が壊れる (実測) |
| cachix/nixpkgs-python | 任意のパッチ版を持てるが、今その要件が無い。nixpkgs より版が遅れ、`follows` するとキャッシュに当たらなくなる |
| pyproject-nix/uv-python.nix (python-build-standalone の FOD) | uv が配布するのと同じバイナリになる。ただし作られたばかりで成熟していない。sysconfig の補正も無い |
| uv の `python-install-mirror` に Nix で取得した tarball を渡す | 展開先は store の外になり、activation の命令も残る |
| devenv | プロジェクト単位の道具で、全体での宣言ではない。例外のプロジェクトの側で使ってよい |

nixpkgs の Python で確かめたこと (pin 済みの rev `a32edd7`、aarch64-darwin):

- `python313` = 3.13.15、`python314` = 3.14.7 で、uv 0.12.17 に埋め込まれた一覧の最新と同じ。
- uv の `pyvenv.cfg` の `home` と `.venv/bin/python` は、**PATH 上で見つけた場所** (symlink) を指し、
  store のパスへは解決されない。本番の構成では `/etc/profiles/per-user/<user>/bin` になる。
- その symlink の先を別の store パス (nixos-25.05 の 3.13.5) に差し替えると、既存の venv はそのまま
  新しいインタープリタで動き、入っていた numpy も import できた。→ **nixpkgs のパッチ版の更新で venv は
  追随し、GC でも壊れない**。uv のマイナー版のリンクが担う役割を、Nix のプロファイルが担う形になる。
  マイナー版が入れ替わる更新は別で、Risks に書く。
- numpy の wheel は、nixpkgs の Python で入って動いた。

### D2. 置く版は「nixpkgs の既定の `python3` と、その 1 つ前のマイナー版」

- 上げる時期を、エコシステムの準備ができたかで判断している nixpkgs に任せる。CPython の新しいマイナー版は
  毎年 10 月に出るが、依存の wheel がそろうまでには数か月かかる。nixpkgs もそれまで既定を上げない。
- 1 つ前の版を並べておき、新しい版へ移る途中の時期を devShell なしで過ごせるようにする。
- 版の番号は書かない。`pkgs.python3.pythonVersion` からマイナー版を取り、1 つ前の属性
  (`python3<minor-1>`) を引く。
  - nixpkgs が既定を上げれば、lock の更新だけで 2 つとも移る。
  - nixpkgs がその属性を消していれば、評価の段階で失敗する (CI で気づける)。
- 退けた案:
  - `[ python314 python313 ]` と直接書く: 読みやすいが、nixpkgs が既定を上げたときに、手で書き換える必要がある。
  - nixpkgs の `python3` だけにする: 移行期に 1 つ前の版が要るプロジェクトが、devShell を持たなければならない。
  - CPython が bugfix 中の版にする: 新しい版が公開された翌日に入り、依存がそろっていない版が並ぶ。

### D3. 名前の衝突は、既定の版に `lib.hiPrio` を付けて解く

`python313` と `python314` は、どちらも `python3`・`python`・`pydoc3`・`idle3`・`python3-config` を
持つので、buildEnv で衝突する (実測)。既定の版に `hiPrio` を付けると、共通の名前は既定の版を指し、
`python3.13` / `python3.14` はそれぞれ残る (実測)。

### D4. uv の設定は `programs.uv.settings` (uv.toml) に書く。環境変数は使わない

```
python-downloads  = "never"        # uv に Python をダウンロードさせない
python-preference = "only-system"  # uv が入れた Python (managed) を使わせない
```

- `home.sessionVariables` は、switch しても既存のシェルや herdr / tmux のサーバー、起動中の Claude Code に
  入らない (CLAUDE.md の既知の罠)。uv.toml は、uv を起動するたびに読まれる。
- 環境変数の `UV_PYTHON_PREFERENCE` は、`--managed-python` を使うコマンドと衝突してエラーになる (実測)。
- `terminal-tooling` の「端末ツールは native モジュールで宣言する」に従い、uv は `programs.uv` で入れ、
  `home.packages` から外す。
- `programs.uv` の `python.*` / `tool.*` は使わない (D1)。
- 注意: `UV_NO_CONFIG=1` を与えると、uv.toml だけでなく **`.python-version` も読まれなくなる** (実測)。

### D5. `UV_PYTHON` は設定しない

devenv は `UV_PYTHON` を設定していたが、`uv pip install` が store の prefix を対象にして externally-managed の
エラーになり、外した (cachix/devenv#2663)。版は `.python-version` と PATH の探索で選ばせる。

### D6. プロジェクトの版の選び方

- `.python-version` は、置いてある版をマイナー版で書く (`3.13`)。パッチ版まで書くと、nixpkgs が上げた
  時点で見つからなくなる。
- それ以外の版が要るプロジェクトは、プロジェクトの `flake.nix` の devShell でその版を PATH に置く
  (`package-management` の既存の要件)。`only-system` の uv は PATH から見つける。
  Claude Code の Bash では direnv が発火しないので、`direnv exec . uv …` と明示する (既知の事実)。
- CLI は `uvx` で使い、使い捨てのスクリプトは PEP 723 と `uv run --script` で書く。これは文書に書く約束で、
  宣言では強制しない。

## Risks / Trade-offs

- [Nix 以外の system Python が抜け穴になる] `only-system` の uv は、Homebrew の Python と
  macOS の `/usr/bin/python3` (3.9) も system として見る。宣言していない版をプロジェクトが求め、それを
  Nix 以外が持っていると、エラーにならずに黙ってそれを使う (例: `.python-version` が `3.9` なら Apple の
  Python)。uv には特定のパスを除外する設定が無い。宣言した版については、PATH で `/etc/profiles/…/bin`
  が `/opt/homebrew/bin` と `/usr/bin` より先にあるので、Nix が勝つ。
  → 「宣言していない版はエラーで止まる」は、どの system Python も持たない版に限って成り立つ。spec は
  この範囲でだけ約束し、抜け穴を明記する。`.python-version` には置いてある版だけを書く、と文書に書く。
  検証の手順に `uv python find` の解決先を確かめる項目を入れる。
- [マイナー版が入れ替わると venv が壊れる] D1 の「venv は追随し、GC でも壊れない」はパッチ版の更新に
  限る (実測もパッチ版の差し替えだけ)。nixpkgs が既定を上げると、D2 により置く 2 つの版が入れ替わり、
  古い方のマイナー版 (例: `python3.13`) がプロファイルから消える。それを指す `.venv` はリンク切れになる。
  汎用の名前 (`python3`) を指す `.venv` はもっと悪く、別のマイナー版に黙って切り替わり、
  `lib/python3.<旧>/site-packages` と合わなくなる (パッケージが見えない、C 拡張の ABI が合わない)。
  → マイナー版が入れ替わる lock の更新は年に 1 回程度。その後に影響を受ける `.venv` を `uv sync` で
  作り直す手順を文書に書く。`.python-version` をマイナー版で書いておけば、venv は `python3.<minor>` を
  指し、汎用の名前を指す場合より壊れ方が分かりやすい (起動しない)。
- [パッチ版は nixpkgs の rev に 1 つ] 特定のパッチ版を使い分けられない。
  → 要件が出たら、そのプロジェクトの devShell で nixpkgs-python などを使う。
- [switch で venv の Python が黙ってパッチ版を上げる] D1 の追随の裏返し。パッチ版は ABI が同じで、
  uv 自身の透過的な更新と同じ振る舞いなので、受け入れる。
- [すべての利用側に Python が 2 つ入る] 閉包が大きくなる。利用側は外せない。
  → 所有者が core に置くと決めた。版は利用側で足せる。
- [素の `python3` の版が nixpkgs しだいで変わる] 既定が 3.14 から 3.15 になれば、プロジェクトの外の
  `python3` も変わる。lock の更新と同時なので、ほかのツールと同じ扱いとして受け入れる。
- [既存の `.venv` が uv の管理する Python を指している] `only-system` の下で、uv がこれを拒んで作り直すかは
  未確認。→ 移行の手順で確かめる (Migration Plan)。

## Migration Plan

1. 変更を build し、`home-manager-path` のエントリと symlink の解決先、生成される `uv.toml` を、前の世代と
   突き合わせる。`drvPath` は意図して変わる。
2. switch の前に、消す対象を非破壊で一覧にして所有者の承認を得る。
   - `uv python list --only-installed --managed-python`
   - その Python を指している `.venv` の一覧
3. 所有者が switch する。
4. 確認:
   - `python3` / `python3.13` / `python3.14` の解決先が `/etc/profiles/…/bin` であること。
   - プロジェクトの中で、`uv python find` の解決先が同じ場所であること。
5. 承認済みの対象について、`uv python uninstall` で uv の管理する Python を消す。各プロジェクトで
   `uv sync` を実行し、`.venv` が `/etc/profiles/…/bin` を指して作り直されることを確かめる。
6. ロールバック: 前の世代に戻すと `uv.toml` が消え、uv は既定 (自動ダウンロード、managed を優先) に戻る。
   `.venv` は次の `uv run` で、uv が入れ直した Python で作り直される。

## Open Questions

- `only-system` の下で、uv の管理する Python を指す既存の `.venv` に `uv run` を実行したとき、uv は
  venv を作り直すのか、エラーになるのか (移行の手順 5 で確かめ、結果を記録する)。
