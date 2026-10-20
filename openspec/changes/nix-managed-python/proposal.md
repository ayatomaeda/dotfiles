## Why

Python の実行環境を、何も宣言していない。uv は `home.packages` にあるが、インタープリタの実体は
uv がプロジェクトごとに必要になった時点でダウンロードし、`~/.local/share/uv/python` に溜めている
(版は入れた時期しだいで、掃除する役がいない)。プロジェクトの外の `python3` は、利用側が宣言した
Homebrew の formula の依存として入った Python か、macOS の `/usr/bin/python3` (3.9) に偶然決まっている。

インタープリタを Nix の store に置き、`flake.lock` で固定し、GC で掃除され、CI の評価で壊れたことが
分かる状態にする。uv はプロジェクトの依存 (`uv.lock`) の道具として使い続け、インタープリタを自分で
入れさせない。

## What Changes

- nixpkgs の既定の `python3` と、その 1 つ前のマイナー版を、共通のパッケージとして宣言する
  (現在の pin では 3.14 と 3.13)。`python3` は既定の版を指す。
- uv を `home.packages` から `programs.uv` へ移し、`uv.toml` を宣言から生成する。
  - `python-downloads = "never"`: uv に Python をダウンロードさせない。
  - `python-preference = "only-system"`: uv が入れた Python を使わせない。
- 次のものは使わない (理由は design)。
  - home-manager の `programs.uv.python.*` / `programs.uv.tool.*` (activation でネットワークに出る)
  - `UV_PYTHON`
  - uv の設定のための `UV_*` 環境変数
- 所有者の手元の移行: `~/.local/share/uv/python` にある uv 管理の Python と、それを指す
  プロジェクトの `.venv` を片づける。**BREAKING (手元の状態)**: 既存の `.venv` は、次の
  `uv run` / `uv sync` で作り直される。
- README / `docs/GUIDE.md` に、Python の版の扱い (置いてある版、`.python-version` の書き方、
  それ以外の版が要るときの devShell、CLI は `uvx`、使い捨てのスクリプトは PEP 723) を書く。

## Capabilities

### New Capabilities

- `python-runtime`: Python のインタープリタを Nix が持ち、uv にはそれだけを使わせる。
  置く版の決め方、uv の設定、プロジェクトの版の選び方、移行のときの確認を定める。

### Modified Capabilities

(なし。uv を `programs.uv` へ移すのは、`terminal-tooling` の「端末ツールは native モジュールで
宣言する」を満たすための実装の変更で、要件は変わらない。それ以外の版をプロジェクトの devShell で
渡すのは、`package-management` の「プロジェクト固有のツールチェーンをグローバルに置かない」を
そのまま使う。)

## Impact

- `modules/common/packages.nix`: `uv` を外し、Python を足す (Python は別のモジュールに分けてもよい)。
- `modules/common/` に `programs.uv` の宣言が加わり、`~/.config/uv/uv.toml` が生成される。
- `home-manager-path` の中身が変わる (`python3` / `python3.13` / `python3.14` などが増える)。
  `drvPath` は変わるので、実体化した出力で比べる。
- すべての利用側に Python が入る。利用側は版を足せるが、外せない。
- 所有者の手元: uv 管理の Python 2 つと、それを指す `.venv` が作り直しの対象になる。
