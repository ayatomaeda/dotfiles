# Design

## Context

動機は proposal.md の Why。所有者の端末 (nix-darwin + home-manager、Apple Silicon、Homebrew は `/opt/homebrew`) で
実測した現状:

```
/etc/zshenv   nix-darwin    NIX_PROFILES の 4 プロファイル x 3 ディレクトリを fpath の先頭に積む
/etc/zshrc    nix-darwin    autoload -U compinit && compinit      <-- 1 回目 (enableGlobalCompInit の既定)
                            autoload -U bashcompinit && bashcompinit
~/.zshrc      home-manager  typeset -U fpath、同じ 12 ディレクトリを後ろに足し直す (mkOrder 510-540)
                            autoload -U compinit && compinit      <-- 2 回目 (enableCompletion の既定、mkOrder 570)
                            zoxide / fzf の初期化 (compdef を使う)
              core          brew shellenv (fpath に Homebrew の補完を足し、FPATH を export する。順序 1000)
```

- core の `modules/common/zsh.nix` は `zstyle` を 3 行置くだけで、`compinit` に触れていない。利用側 (家) も触れていない。
  nix-darwin と home-manager の補完の option はすべて既定値 (評価で確認)。
- 対話シェルは、端末のアプリ、マルチプレクサのペイン、エージェントのシェルのどれも macOS の `/bin/zsh` 5.9 (ログイン
  シェル)。`PATH` の `zsh` は Nix の zsh 5.9.2 (`/etc/profiles/per-user/<user>/bin` と `/run/current-system/sw/bin`)。
- `compinit` は dump の 1 行目の「ファイルの個数」と「zsh の版」の両方を今のシェルと比べ、どちらかが違えば作り直す
  (zsh 同梱の `compinit` のソースで確認)。
- 現状の起動 (3 回の中央値):

  | 起動 | 時間 | dump |
  |---|---|---|
  | 端末のアプリが起動したシェル | 0.12 s | 書き換わらない |
  | そのシェルから起動したシェル (親子 2 回分) | 1.02 s | 毎回作り直す |
  | Nix の zsh を起動した直後の、端末のアプリが起動したシェル | 0.45 s | 作り直す |

- 個数が揺れる仕組み: 端末のアプリが起動したシェルでは、2 回の `compinit` がどちらも Homebrew の補完の無い fpath を
  数える (1023)。そのシェルから起動したシェルは、export された `FPATH` (Homebrew の補完を含む) を受け継ぎ、`/etc/zshenv`
  がもう一度積むので、1 回目は重複込み、2 回目は `typeset -U` の後で数える。個数が合わず、2 回とも作り直す。
- 同じ型の報告と修正 (2026 年):
  - nix-darwin と home-manager の二重の `compinit` を `enableGlobalCompInit = false` で直したもの: ttak0422/dotfiles PR #2
    (dump が 2 つの個数で交互に作り直され、ログイン 1438 ms から 375 ms)、didactiklabs/nixbook PR #2740、
    dryvist/nix-darwin PR #2747 (`/bin/zsh` と Nix の zsh が版の無い 1 つの dump を書き換え合う)。
  - `brew shellenv` の `FPATH` で、新しいタブと子のシェルの個数が違い、交互の起動で作り直すもの: urban-side/setup_tools
    PR #17 (979 と 991)。ohmyzsh/ohmyzsh issue #13720 (`brew shellenv` が足す重複で毎回作り直す。設定の欠陥として閉じた)。
  - Homebrew は、子のシェルにも Homebrew の補完を届けるために `brew shellenv` に `export FPATH` を足している
    (Homebrew/brew issue #21879、PR #21910)。Homebrew の文書は、補完のディレクトリを `compinit` の前に fpath へ入れる
    よう書いている (docs.brew.sh の Shell Completion)。
  - zsh の開発者は、複数の版の zsh を使うなら dump を版ごとのファイルにするよう勧めている (zsh-users 2004 年)。
  - home-manager には二重の `compinit` の相談 (issue #3965) があるが、推奨は出ていない。nix-darwin の文書は
    `enableGlobalCompInit` を「fpath を広げて自分で `compinit` を呼ぶなら切る」ものとして説明するだけ。

## Goals / Non-Goals

**Goals:**

- 端末のアプリが起動したシェル、シェルから起動したシェル、`/bin/zsh` と Nix の zsh を混ぜて起動しても、dump が
  作り直されないようにする。
- 補完の初期化を home-manager の `~/.zshrc` に閉じ、nix-darwin の無い環境でも同じ `~/.zshrc` が動く形を保つ。
- 前提 (home-manager を使わないアカウントの対話 zsh には補完の初期化が無い) を core の文書と手引きに残す。

**Non-Goals:**

- **zsh を 1 つにそろえること。** ログインシェルを Nix の zsh にするには、管理者ユーザーのシェルを宣言する必要があるが、
  nix-darwin の正規の道 (`users.knownUsers`) は管理者を入れるなと文書にあり、既存のユーザーのシェルは宣言では変わらない
  という報告もある (nix-darwin issue #361)。ログインシェルが `/nix` のボリュームに依るようになり、sshd を公開鍵だけにした
  構成で起動直後の締め出しの危険も増える。逆に `PATH` から Nix の zsh を外す道は、nix-darwin の `programs.zsh.enable` が
  `pkgs.zsh` を無条件に入れ、選ぶ option が無いので無い。どちらも補完の初期化の問題を直すのには要らない (D4 で害は消える)。
- `brew shellenv` の出力 (`FPATH` の export、`PATH` の重複) を変えること。
- `compinit` の形 (`-C`、日次の検査、`zcompile`) の最適化。
- 利用側のリポジトリの変更。

## Decisions

- **D1. 止めるのは nix-darwin 側 (`/etc/zshrc`)。home-manager 側 (`~/.zshrc`) を残す。**
  home-manager の `compinit` は fpath の組み立て (mkOrder 510-540) の後、`compdef` を使う初期化 (zoxide、fzf) の前に
  home-manager 自身が並べるので、順序を core が管理しなくてよい。standalone の home-manager でも同じ `~/.zshrc` が動く。
  同じ型の修正 (Context) もすべてこの向き。nix-darwin の `compinit` の行は `interactiveShellInit` の後に置かれる
  不具合 (nix-darwin issue #1699) も持つので、止めればそれも踏まない。
  退けた案: (a) home-manager の `enableCompletion = false` — nix-darwin の無い環境で `compinit` が無くなり、zoxide / fzf の
  初期化が `compdef: command not found` で落ちる。`modules/common` の補完が darwin 専用のファイルに依存する。`~/.zshrc` の
  中で fpath に足したもの (Homebrew を含む) が dump に入らない。(b) `compinit -C` で 2 回目を安くする — dump が検査されず、
  パッケージを変えても補完が古いまま残る。
- **D2. option は nix-darwin の `programs.zsh.enableGlobalCompInit = false`。`enableCompletion` と `enable` は触らない。**
  切ると `/etc/zshrc` から `compinit` の行だけが消える (評価で確認)。`enableCompletion = false` は `nix-zsh-completions` も
  消し、`enable = false` は `/etc/zshenv` ごと消して Nix の環境 (`PATH`、`NIX_PROFILES`) が対話シェルに入らなくなる。
  `bashcompinit` (`enableBashCompletion`) は残す。`compinit` の前に `bashcompinit` を読んでも、`/bin/zsh` と Nix の zsh の
  どちらも警告もエラーも出さない (実測)。
- **D3. Homebrew の行は、home-manager の `typeset -U` と fpath の組み立ての後、`compinit` の前に置く。`FPATH` の export は
  残す。** core の `zsh.nix` の darwin の `initContent` を `lib.mkOrder 550` にする (home-manager の 510-540 の後、570 の前)。
  前に置くと、端末のアプリが起動したシェルの dump にも Homebrew の補完が入り、`typeset -U` が受け継いだ重複を除くので、
  端末のアプリが起動したシェルとその子の `/bin/zsh` が同じ個数 (1029) を数える (模擬で確認)。`PATH` の並べ直しは
  `brew shellenv` の直後のまま動かす (順序 1000 までの初期化は絶対パスで呼ばれ、`PATH` に依らない)。
  退けた案: `brew shellenv` の後で `typeset +x FPATH` として export を外す — 外しても外さなくても dump は同じく安定し
  (模擬で確認)、Nix の zsh の子の `/bin/zsh` も別の版の関数を読み込まなかった (`_git` は `/usr/share/zsh/5.9/functions`
  から読まれ、fpath に 5.9.2 のディレクトリは無かった)。export は Homebrew が子のシェルに補完を届けるために意図して足した
  もので、外すと core の外で使う子のシェル (`zsh -f` など) の補完が変わる。根拠の無い上書きはしない。
- **D4. dump は zsh の版ごとのファイルにする。** home-manager の `programs.zsh.completionInit` を
  `autoload -U compinit && compinit -d "${ZDOTDIR:-$HOME}/.zcompdump-$ZSH_VERSION"` にする (既定の置き場所に版を足す)。
  1 つの dump のままでは、Nix の zsh を起動するたびに `/bin/zsh` の dump が捨てられ、その次の `/bin/zsh` がまた捨てる
  (模擬で 0.82 s と 0.55 s)。版ごとにすれば、混ぜた 8 回の起動で一度も書き換わらない。`zsh` と打つのは人よりエージェント
  (`zsh -ic`) に多い。
  退けた案: zsh を 1 つにそろえる (Non-Goals)。dump の名前を fpath のハッシュにする (ohmyzsh issue #13720 の提案の 1 つ) —
  fpath は D3 で起動の仕方に依らなくなるので要らず、構成を変えるたびに古い dump が増える。
- **D5. `drvPath` は意図的に変わる。照合は生成物と実体で行う。** (1) 利用側で `--override-input` の build の `etc/zshrc` と
  現行の `/etc/zshrc` の差が `compinit` の 1 行だけ。(2) home-manager の `home-files` の木の差が `.zshrc` だけで、その差が
  Homebrew の行の移動と `compinit` の `-d` だけ。(3) build した `etc/zshrc` と `.zshrc` を作業用のディレクトリに置き、
  `NOSYSZSHRC=1` と `ZDOTDIR` で読ませる模擬で、spec の「混ぜる」Scenario を通す (Context と同じ手順)。(4) switch の後、
  同じ Scenario を本物のシェルで通す (利用側の作業。Migration Plan)。
- **D6. 文書の置き場所。** core の `CLAUDE.md` の「踏むと痛い箇所」に、症状から引ける 1 項 (シェルから起動したシェルの
  起動が重い、dump が書き換わる。原因は dump の鍵の揺れ。3 つの宣言を外さない。確かめ方)。`README.md` の「利用側が
  与えるもの」に 1 行 (core の前提: 補完の初期化は home-manager の `~/.zshrc` の 1 回。利用側が与えるもの: home-manager の
  darwin モジュールの読み込みと、home-manager を使わないアカウントの対話 zsh には補完の初期化が無いこと)。
  `docs/CONSUMER-GUIDE.md` は 1 節「家の前提」に、家の形 (Mac は 1 ユーザーで、そのユーザーが home-manager を使う) と
  その前提を書き、仕組みは README へのリンクで指す。読み手への指示は書かない。`最終照合:` は、この記述を家の構成
  (ユーザーの数と home-manager の読み込み) と突き合わせた日にする。家の構成はこの change で変わらないので、apply の時点で
  突き合わせられる。

## Risks / Trade-offs

- [home-manager を使わないアカウント (別の macOS ユーザー) の対話 zsh で補完が初期化されない] → core の darwin
  モジュールは home-manager の読み込みをすでに前提にしている。前提として README と手引きに書く (D6)。
- [home-manager が `compinit` の順序 (mkOrder 570) や fpath の組み立て (510-540) の順序を変える] → Homebrew の行
  (550) が `compinit` の後か `typeset -U` の前に回る。どちらも評価では気づけないので、`CLAUDE.md` の項に、lock の更新で
  home-manager が上がったときは生成された `~/.zshrc` の並びを見ることを書く。
- [home-manager の `compinit` が消える] → core 自身が zoxide と fzf を有効にしているので、`compdef` のエラーで対話シェルに
  すぐ出る。
- [nix-darwin が `enableGlobalCompInit` を改名・廃止する] → 評価が止まるので CI と lock の更新で気づく。
- [古い `~/.zcompdump` が残る] → 読まれないだけ。消すかは所有者が決める。
- [macOS の更新で `/bin/zsh` の版が上がる] → 新しい版の dump が 1 回作られるだけ。古い版のファイルが残る。

## Migration Plan

1. core: この change を、モジュールと `CLAUDE.md`・`README.md` の 1 コミットと、手引きの 1 コミットで PR にする。マージの
   前に、利用側 (家) で `--override-input core path:../dotfiles` の build と模擬で D5 (1)(2)(3) を確かめる。
2. 利用側 (家): `nix flake update core` を PR にして、両方の Mac で switch する。switch の後に D5 (4) を確かめる。家の CI の
   手引きのレビューは、手引きの 1 節の追記を読んで「影響なし」になるはず。
3. ほかの利用側: lock を上げて switch する。それまでは自分の darwin モジュールに `enableGlobalCompInit = false` を置いて
   しのいでよい (同じ値の重複は受け入れられる。実測)。
4. 戻すとき: 宣言を外す。dump は `compinit` が作り直すので手作業は要らない。

## Open Questions

(なし)
