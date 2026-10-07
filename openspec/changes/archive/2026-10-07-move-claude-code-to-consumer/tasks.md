## 1. 基準の記録

- [x] 1.1 利用側 (所有者の家の構成) で、今の lock の版から各ホストの drvPath、`home-files` の `.claude/settings.json` の中身と statusline の store パス、`home-manager-path` のエントリ一覧、Brewfile の行を記録する

## 2. core から外す

- [x] 2.1 `modules/common/claude-code.nix` を削除し、`modules/common/default.nix` の import から外す
- [x] 2.2 `claude/statusline-command.sh` を削除する (`claude/` ごと)
- [x] 2.3 `modules/darwin/homebrew.nix` の casks から `"claude"` と、`claude-code` を除外した理由のコメントを外す
- [x] 2.4 `modules/common/terminal.nix` の `programs.jq` と `programs.ripgrep` のコメントを、core に置く一般的な理由に書き直す (design D1)。冒頭の「人間と Claude Code が同じシェル構成を共有」も「人間と非対話のエージェント (Claude Code、Codex など)」に改める (README の端末のツールの節も同じ)。シェルスナップショットへの配慮のコメントは変えない
- [x] 2.5 評価用の例の構成 (`darwinConfigurations.example`) を評価し、`programs.claude-code.enable` が false で、cask のリストに `claude` が無いことを確かめる

## 3. 文書

- [x] 3.1 `README.md`: モジュールの表と構造の表から `claude-code` と `claude/` を外す。「Claude Code は native インストーラ」の節と、保存されない操作の表の Claude Code の行と後続の説明を外す。利用側への移行の注記 (lock を更新すると `~/.claude/settings.json` と cask `claude` が無くなる。使うなら自分で宣言し、lock の更新と同じコミットで行う。`cleanup = "uninstall"` では足さないとデスクトップ版が削除される。lock を自動で更新する仕組みがある利用側は、core だけを上げるその PR をそのまま入れない。利用側で「Claude Code の設定と cask がある」ことを assertion にしておくと、その PR は評価で止まる) を足す。端末のツールの表の「エージェントが走る」の説明を確かめる
- [x] 3.2 `docs/GUIDE.md`: 「Claude Code のステータスライン」の節と、「書く場所」の表の Claude Code の 2 行、保存されない操作の Claude Code の項を外す
- [x] 3.3 `CLAUDE.md`: 構造の図から `claude-code` と `claude/` を外す。「アプリの設定画面での変更は保存されない」から Claude Code の記述と `programs.claude-code.marketplaces` の項を外す (herdr の記述は残す)。シェルスナップショット、`TRAPINT`、`home.sessionVariables`、herdr の連携の注意、`.hm-bak` の注意 (例の `~/.claude/settings.json` を含む) は残す
- [x] 3.4 `rg -n -i 'claude' --glob '!openspec/changes/**'` で残った記述を一覧し (`openspec/specs/` を含む)、design D1 の「残す」に当たるものだけが残っていることを確かめる

## 4. 確認 (利用側で、手元のクローンを指して。switch はしない)

- [x] 4.1 利用側に、外したものと同じ宣言 (`programs.claude-code`、statusline のスクリプト、cask `"claude"`) を足し (コミットしない)、`--override-input core path:../dotfiles` で各ホストを評価と build する
- [x] 4.2 1.1 と比べる: `.claude/settings.json` の中身と statusline の store パスが一致する。`home-manager-path` のエントリが一致する (`jq` が残る)。Brewfile の行の集合が一致する
- [x] 4.3 `nix run nixpkgs#nix-diff -- <前の drv> <後の drv>` で、drvPath の差が Brewfile の行の順序 (とそれを含む derivation) だけであることを確かめる。ほかの差が出たら、原因を特定して記録するまで先へ進まない
- [ ] 4.4 宣言を減らす変更なので、利用側の Mac で `brew bundle cleanup` の dry-run を、1.1 の Brewfile と 4.1 で build した Brewfile のそれぞれに `--file` で向けて実行し、削除対象の一覧が同じで `claude` を含まないことを示す (`HOMEBREW_NO_AUTO_UPDATE=1`)
- [x] 4.5 利用側の宣言を足さずに評価し、`~/.claude/settings.json` が生成されないことと、Brewfile に `claude` が無いことを確かめる (ほかの利用側が lock を更新したときの姿)

## 5. archive とマージ

- [x] 5.1 利用側の禁止語の検査を通す
- [x] 5.2 `openspec archive move-claude-code-to-consumer` で delta を `openspec/specs/` に反映し、この PR に積む
- [x] 5.3 PR の本文に、利用側への影響 (3.1 の移行の注記と同じ内容) を書く。利用側の構成の名前は書かない
- [ ] 5.4 この PR のレビューを受けてマージする。lock を自動で更新する利用側が、core だけが上がった lock を止める assertion を置く場合は、それが利用側に入ってからマージする。利用側の lock の更新と宣言の追加は、利用側の change で 1 コミットにして行う

## 記録 (所有者の家の構成。2 台の Mac とも同じ結果)

core は `572e806` (コードの変更) を rev で指して照合した。

| 比べたもの | 結果 |
|---|---|
| `darwin-rebuild build` | 2 台とも成功 |
| drvPath | 変わる (見込みどおり) |
| `.claude/settings.json` | 中身も store パスも同一。利用側の PreToolUse の hook も入っている |
| `home-files` | 同一 |
| ステータスラインのスクリプト | store パスが同一 (`…-claude-statusline`) |
| `home-manager-path` | 同一 (807 件の解決先まで) |
| Brewfile の行の集合 | 同一 |
| Brewfile の並び | `cask "claude"` の位置だけが違う |
| `nix-diff` | 差は Brewfile の drv だけ |
| `brew bundle cleanup` の dry-run | 1 台目は移行前・移行後とも削除対象なし。2 台目は ssh がつながらず未確認 (利用側の適用の前に行う) |

4.5: 利用側の宣言を足さずに core の実装を指すと、利用側が置いた assertion (Claude Code の設定と cask があること) で
評価が止まる。宣言の無い姿は、評価用の例の構成で確かめた (2.5)。
