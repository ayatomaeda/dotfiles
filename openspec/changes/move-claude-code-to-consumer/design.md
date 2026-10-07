## Context

core の中で、Claude Code に依存しているものは次のとおり。

```
modules/common/claude-code.nix     programs.claude-code (package = null) と settings、statusline の assertion
claude/statusline-command.sh       ステータスラインの本体 (jq / git / date を呼ぶ)
modules/darwin/homebrew.nix        cask "claude" (デスクトップ版)
modules/common/terminal.nix        programs.jq   … コメントの根拠は「statusline が呼ぶ」
                                   programs.ripgrep … コメントの根拠は「Claude Code の内部の rg しか無かった」
```

core を使う環境ごとに、使うエージェントは違いうる (Claude Code を使わない環境もありうる)。
リストに置いたもの (`home.packages`、Homebrew のリスト、`programs.*` の有効化) は利用側で引けない。

Claude Code を名前で挙げているが、Claude Code の設定には依存していない記述もある。

- `programs.zsh.shellAliases` で既存のコマンド名を奪わない方針 (エージェントのシェルスナップショットに載るため)
- `TRAPINT` の非対話の分岐、tmux の `preexec` の注記、`home.sessionVariables` の注意
- herdr の連携コマンドで `~/.claude` を宣言の外で変えない要件

## Goals / Non-Goals

**Goals:**

- core が、特定のエージェント製品の設定と、その製品のためだけの依存を持たない。
- 所有者の家の構成では、移した後も Claude Code の設定、ステータスライン、デスクトップ版が今と同じに保たれる。
- 利用側が lock を更新したときに何が消えるのかを、文書で分かるようにする。

**Non-Goals:**

- Claude Code 以外のエージェント (Codex など) の設定を core に足すこと。
- シェルスナップショットへの配慮を外すこと。どのエージェントでも、非対話のシェルはこの構成を読む。
- Claude Code のパッケージの扱いを変えること (今も入れていない。native インストーラが入れる)。

## Decisions

### D1. 移す範囲は「Claude Code のためだけにあるもの」に限る

| 項目 | 結論 | 理由 |
|---|---|---|
| `claude-code.nix`、`claude/statusline-command.sh` | 利用側へ移す | Claude Code の設定そのもの |
| cask `"claude"` | 利用側へ移す | Claude のアプリそのもの |
| `programs.jq` | core に残す | JSON を扱う一般的な道具。エージェント (Codex を含む) も人間も呼ぶ |
| `programs.ripgrep` / `fd` | core に残す | エンジニアが日常的に使う検索の道具。エージェントも呼ぶ |
| `herdr` | core に残す | Claude Code と Codex のどちらを並べるときにも使う |
| シェルスナップショットへの配慮 | core に残す | 非対話のエージェント全般のための、シェル側の性質 |

`jq` と `rg` のコメントは、導入したときの Claude Code 固有の経緯ではなく、今 core に置く理由を書く。
経緯だけを根拠にすると、次に「Claude のためだけのもの」を探す人が誤って移す。

代案: `jq` も statusline と一緒に移す。→ 採らない。core に置く理由が statusline 以外にもあり、移すと core を使う
ほかの環境から `jq` が消える。利用側の statusline は core の `jq` に頼る (依存は利用側 → core の向きで、原則に反しない)。

### D2. 利用側に移す宣言は、今の宣言と同じ値にする

ステータスラインのスクリプトは、中身と `writeShellScript` の名前 (`claude-statusline`) が同じなら store のパスも同じになる。
`settings.json` は `builtins.toJSON` で生成され、キーは並べ替えられるので、宣言するモジュールが変わっても中身は変わらない。
したがって、所有者の家の構成では `~/.claude` の生成物が完全に一致することを確かめられる。

### D3. 振る舞い不変の確認は、実体化した出力の比較で行う

cask のリストは読み込み順につながり、nix-darwin の Brewfile は並べ替えられない。`"claude"` が core のリストから利用側の
リストへ移ると、Brewfile の行の順序が変わり、drvPath は一致しない。そこで次を突き合わせる。

- `home-files` の木 (`~/.claude/settings.json` の中身と、statusline の store パス)
- `home-manager-path` のエントリ一覧 (`jq` が残っていること)
- Brewfile の行の集合 (順序を除いて一致)
- `nix-diff` で、差が Brewfile (とそれを含む derivation) だけであること

### D4. 利用側の追加は、lock の更新と同じコミットで行う

```
① core の PR をマージ         利用側の lock は古い版を指したまま。影響なし
② 利用側の 1 コミット         nix flake update core + Claude Code の宣言の追加
```

②を分けると、間の世代で `~/.claude/settings.json` が消え、`cleanup = "uninstall"` の構成では Claude のデスクトップ版が削除される。
逆に、①より前に利用側で宣言を足すと、core と利用側の両方が `programs.claude-code.settings.statusLine` などを定義する。
同じ値でも、マージの規則に頼る状態になるので採らない。

### D5. herdr の連携の要件は core に残す

`herdr integration install claude` は herdr のコマンドで、herdr は core が入れる。要件の対象を「利用側が Claude Code の設定を
宣言から生成している環境」に絞り、Scenario からは core のファイルのパスを外す。Claude Code の設定を宣言しない利用側では
`~/.claude/settings.json` は書き込めるので、連携コマンドが壊すものは無い。

### D6. Claude Code 固有の注意は、利用側の文書へ移す

core の README と CLAUDE.md にある次の記述は、Claude Code の設定を宣言する側の注意なので外す。所有者の家の構成の文書へ移す。

- `programs.claude-code.marketplaces` を使わない理由
- `/config`・`/theme`・権限の「常に許可」・プラグインの切り替えが保存されないこと
- Claude Code が `~/.claude/settings.json` を読み取り専用のまま扱うこと
- Claude Code を native インストーラで入れる理由 (Homebrew 管理だと自動更新が止まる)

シェルスナップショットの注意は core に残す。

## Risks / Trade-offs

- [ほかの利用側で、lock の更新とともに Claude Code の設定とデスクトップ版が消える] → README に移行の注記を書き、
  PR の本文にも書く。利用側の構成の名前は書かない。
- [利用側の statusline が core の `jq` に頼る。core が将来 `jq` を外すと statusline が `jq not found` を出す]
  → 利用側のコメントに、core の `jq` を前提にすることを約束として書く。core の側には利用側のことを書かない
  (依存は一方向)。statusline は `jq` が無ければ `jq not found` を表示して止まるだけで、Claude Code 自体は動く。
- [文書から Claude Code の記述を外しすぎて、シェルスナップショットの注意まで消す] → D1 の表で残すものを決め、tasks で
  個別に確かめる。

## Migration Plan

1. core: 削除と文書の修正。所有者の家の構成で `--override-input core path:../dotfiles` を付け、宣言を足した状態で
   D3 の比較を行う (switch はしない)。
2. core の PR をマージする。
3. 利用側: `nix flake update core` と宣言の追加を 1 コミットにした PR を作り、マージしてから所有者が switch する。

戻すときは、利用側の②のコミットをまとめて revert する。lock だけを戻すと、古い core と利用側の両方が Claude Code を宣言する
(D4 で避けた状態になる)。

## Open Questions

(なし)
