## 1. 変更前の記録

- [ ] 1.1 利用側のリポジトリで、変更前の `home-manager-path` のエントリ一覧と、`home-files` の木を記録する (比べる対象)
- [ ] 1.2 移行で撤去する対象を非破壊で一覧にする: `uv python list --only-installed --managed-python` と、`~/git` の配下で `.venv/bin/python` が `~/.local/share/uv/python` を指しているプロジェクト (記録にはプロジェクトの名前を書かず、件数と版だけを残す)

## 2. 宣言

- [ ] 2.1 `modules/common/python.nix` を作り、`modules/common/default.nix` の imports に足す
- [ ] 2.2 `home.packages` に、`lib.hiPrio pkgs.python3` と、`pkgs.python3.pythonVersion` から導出した 1 つ前のマイナー版を置く。版の番号は書かない。導出のしかたをコメントに残す (D2)
- [ ] 2.3 `programs.uv.enable = true` と `programs.uv.settings` (`python-downloads = "never"`、`python-preference = "only-system"`) を宣言する。`programs.uv.python.*` / `tool.*` は使わない理由 (activation でネットワークに出る) をコメントに残す (D1, D4)
- [ ] 2.4 `modules/common/packages.nix` から `uv` を外す (`programs.uv` が入れる)
- [ ] 2.5 `UV_PYTHON` と `UV_*` の環境変数を設定しない理由をコメントに残す (D4, D5)

## 3. build と比較 (所有者の switch の前)

- [ ] 3.1 利用側で `--override-input core path:../dotfiles` を付けて `darwin-rebuild build` する。switch はしない
- [ ] 3.2 `home-manager-path` の差が、`python3` 系の実行ファイルの追加と `uv` の出所の変化だけであることを確かめる。`python3` が既定の版 (`hiPrio`) を、`python3.<前の版>` がもう一方を指すこと
- [ ] 3.3 `home-files` の差が `.config/uv/uv.toml` の追加だけであることを確かめ、その中身を確かめる
- [ ] 3.4 評価の検出を確かめる: 導出した属性名が存在しない nixpkgs を想定し、評価が失敗することを `nix eval` で確認する (例: 導出元の版を一時的に差し替えた式で評価する。リポジトリには残さない)

## 4. 文書

- [ ] 4.1 README / `docs/GUIDE.md` に Python の節を足す: 置いてある版の決まり方、`.python-version` はマイナー版で書くこと、宣言していない版はプロジェクトの devShell で渡すこと (エージェントからは `direnv exec .`)、CLI は `uvx`、使い捨てのスクリプトは PEP 723 と `uv run --script`
- [ ] 4.2 CLAUDE.md の構造の一覧に `python` を足す。「踏むと痛い箇所」に次の 2 つを足す
  - `UV_NO_CONFIG` は `.python-version` も無効にすること
  - `only-system` の uv は Homebrew の Python も候補に数えること (宣言していない版を求めると黙って使う)
- [ ] 4.3 README の direnv の節の「mise を採らない」説明と、今回の方針 (ランタイムの版の情報源は flake) が矛盾しないことを確かめる

## 5. 適用と移行 (所有者が switch した後)

- [ ] 5.1 1.2 の一覧を所有者に示し、撤去の承認を得る
- [ ] 5.2 所有者が、利用側で `nix flake update core` を実行し、そのコミットから switch する
- [ ] 5.3 `python3` / `python3.13` / `python3.14` の解決先が `/etc/profiles/per-user/<user>/bin` であることを確かめる。Claude Code の Bash でも確かめる
- [ ] 5.4 撤去の前に、`only-system` の下で、uv の管理する Python を指す既存の `.venv` に `uv run` を実行したときの振る舞い (作り直すか、エラーになるか) を 1 つのプロジェクトで確かめ、design の Open Questions に結果を記録する
- [ ] 5.5 承認済みの対象を `uv python uninstall` で撤去する。各プロジェクトで `uv sync` を実行し、`.venv/bin/python` が `/etc/profiles/per-user/<user>/bin` を指すことを確かめる
- [ ] 5.6 プロジェクトの中で `uv python find` の解決先が `/opt/homebrew` ではないことを確かめる
- [ ] 5.7 宣言していない版 (例: `3.12`) を `.python-version` に書いた一時ディレクトリで、`uv sync` がダウンロードせずにエラーで止まることを確かめる
