# Design

## Context

動機は proposal.md の Why。所有者の端末 (nix-darwin + home-manager、Apple Silicon) で実測した現状:

```
/etc/zshenv   nix-darwin    NIX_PROFILES の 4 プロファイル x 3 ディレクトリを fpath の先頭に積む
/etc/zshrc    nix-darwin    autoload -U compinit && compinit      <-- 1 回目 (enableGlobalCompInit の既定)
                            autoload -U bashcompinit && bashcompinit
~/.zshrc      home-manager  typeset -U fpath、同じ 12 ディレクトリを後ろに足し直す (mkOrder 510-540)
                            autoload -U compinit && compinit      <-- 2 回目 (enableCompletion の既定、mkOrder 570)
                            zoxide init / fzf --zsh (compdef を使う)
                            core の initContent (zstyle 3 行、brew shellenv、…)
```

- core の `modules/common/zsh.nix` は `zstyle` を 3 行置くだけで、`compinit` には触れていない。利用側 (家) も触れて
  いない。nix-darwin の `programs.zsh.enable` / `enableCompletion` / `enableBashCompletion` / `enableGlobalCompInit`、
  home-manager の `programs.zsh.enableCompletion` はすべて既定値 (評価で確認)。
- `compinit` は `fpath` の中の補完ファイルの個数を dump の 1 行目 (`#files: N`) と比べ、違えば作り直す。
- 端末のアプリが直接起動した login shell では、1 回目と 2 回目の `fpath` は同じ集合 (15 ディレクトリ、1023 ファイル) で、
  dump は書き換わらず起動は 0.15 秒。
- **シェルから起動したシェル**では違う。core の `brew shellenv` が `FPATH` を export するので、子のシェルは親の `fpath`
  を持って始まり、`/etc/zshenv` が同じ 12 ディレクトリをもう一度先頭に積む。1 回目の `compinit` は重複込みで数え
  (40 ディレクトリ、3141 ファイル)、2 回目は `typeset -U` の後で数える (20 ディレクトリ、3027 ファイル)。個数が
  違うので 1 回目が dump を作り直し、2 回目も作り直す。起動は 1.35 秒、`~/.zcompdump` は起動のたびに更新される。
  herdr / tmux のペイン、Claude Code のシェル、`zsh` と打ったシェルがすべてこの経路。
- `/etc/zshrc` の `compinit` を飛ばす (`NOSYSZSHRC=1`) と 0.17 秒、dump は更新されない。nix-darwin の
  `enableGlobalCompInit = false` で生成した `/etc/zshrc` を `~/.zshrc` の前に読む模擬でも 0.18 秒、dump は更新されない。
- `programs.zsh.enableGlobalCompInit = false` の評価結果は、現行の `/etc/zshrc` との差が `compinit` の 1 行だけ
  (`extendModules` で評価して diff)。同じ option を 2 つのモジュールが同じ値で定義しても評価は通る (bool は等しい値の
  重複を受け入れる)。

## Goals / Non-Goals

**Goals:**

- 対話 zsh の `compinit` を 1 回にし、シェルから起動したシェルでも dump の作り直しが起きないようにする。
- 補完の初期化を home-manager の `~/.zshrc` に閉じ、nix-darwin の無い環境でも同じ `~/.zshrc` が動く形を保つ。
- 前提 (home-manager を使わないアカウントの対話 zsh には補完の初期化が無い) を core の文書と手引きに残す。

**Non-Goals:**

- `brew shellenv` の `FPATH` の export と、それによる `fpath` の重複の整理。`compinit` が 1 回になれば個数の比較は
  `~/.zshrc` の中で閉じ、重複があっても作り直しは起きない。重複そのものと、Homebrew の `site-functions` が
  最初のシェルでは `compinit` の後に `fpath` に入る (= 端末のアプリが直接起動したシェルでは Homebrew の補完が dump に
  入らない) 件は、観察として残し別件にする。
- `~/.zshrc` の `compinit` の形 (`-C`、dump の置き場所、キャッシュの日次更新) の変更。
- 利用側のリポジトリの変更 (lock の更新と switch、会社側の暫定の宣言)。

## Decisions

- **D1. 止めるのは nix-darwin 側 (`/etc/zshrc`)。home-manager 側 (`~/.zshrc`) を残す。**
  home-manager の `compinit` は `fpath` の整理 (mkOrder 510-540) の後、`compdef` を使う初期化 (zoxide、fzf) の前に
  home-manager 自身が並べるので、順序を core が管理しなくてよい。standalone の home-manager (Linux、nix-darwin を使わない
  Mac) でも同じ `~/.zshrc` が動く。
  退けた案: (a) home-manager の `enableCompletion = false` — nix-darwin の無い環境で `compinit` がどこにも無くなり、
  zoxide / fzf の初期化が `compdef: command not found` で落ちる。macOS 自身の `/etc/zshrc` は `compinit` を呼ばない。
  `modules/common` の補完が darwin 専用のファイルに依存し、「分岐はモジュールの内部で」の原則に反する。`~/.zshrc` の
  中で `fpath` に足したもの (home-manager の `plugins` など) が、先に終わった `compinit` の dump に入らない。
  (b) home-manager 側を `compinit -C` にして 2 回目を安くする — standalone の環境で dump が二度と検査されず、
  パッケージを変えても補完が古いまま残る。(c) 1 回目と 2 回目の `fpath` をそろえて個数を一致させる — `/etc/zshenv` は
  nix-darwin の生成物で、そろえる手段が `FPATH` の export を止めること (Non-Goal) か、`~/.zshrc` の `typeset -U` を
  外すことしか無く、どちらも別の崩れ方をする。
- **D2. 使う option は `programs.zsh.enableGlobalCompInit = false`。`enableCompletion` と `enable` は触らない。**
  nix-darwin はこの option を「利用者が `fpath` を広げて自分の `compinit` を呼ぶ場合に切るもの」として用意しており、
  切ると `/etc/zshrc` から `compinit` の行だけが消える。`enableCompletion = false` にすると `nix-zsh-completions` も
  `systemPackages` から消える (`enableGlobalCompInit` の既定値の元でもある)。`enable = false` にすると `/etc/zshenv` ごと
  消え、Nix の環境設定 (`PATH`、`NIX_PROFILES`) が対話シェルに入らなくなる。
  `enableBashCompletion` (= `bashcompinit`) は残す。`bashcompinit` は `complete` / `compgen` の関数を定義するだけで、
  `compdef` を呼ぶのは `complete` が使われたとき。そのときには `~/.zshrc` の `compinit` が済んでいる。apply で
  `bashcompinit` が `compinit` 無しで警告を出さないことを確かめ、出るなら `enableBashCompletion = false` も足す。
- **D3. 置き場所は core の `modules/darwin/default.nix`。** core が darwin と home のモジュールを対で出していること自体が
  原因で、対で使えば利用側に関係なく起きる。利用側に置くと、利用側ごとに同じ 1 行と理由を持つことになる。option には
  しない (ホストが値を与えるものでも、ホスト依存の情報から導くものでもない)。
  利用側が lock を上げるまで、自分の darwin モジュールに同じ `enableGlobalCompInit = false` を置いてしのいでも、
  core が上がった後に同じ値の重複として受け入れられる (実測)。消すのは lock を上げた後でよい。
- **D4. `drvPath` は意図的に変わる。照合は実体で行う。** 変わる生成物は `/etc/zshrc` だけのはずなので、次を突き合わせる:
  (1) `extendModules` で評価した `/etc/zshrc` の差分が `compinit` の 1 行だけ (build の前。apply では build 結果の
  `etc/zshrc` と現行の `/etc/zshrc` の diff)。(2) `home-files` の木 (`~/.zshrc` を含む) が前の世代と同一。(3) switch の後、
  シェルから起動したシェルを 2 回続けて起動して `~/.zcompdump` の更新時刻が変わらない。(4) 起動時間が端末のアプリが
  直接起動したシェルと同じ桁 (0.2 秒程度)。(5) `whence -w _rg` が function、`NOSYSZSHRC=1 zsh -ic exit` が
  `compdef` のエラーを出さない。
- **D5. 文書の置き場所。** core の `CLAUDE.md` の「踏むと痛い箇所」に症状から引ける形で 1 項 (シェルから起動した
  シェルの起動が 1 秒以上かかり `~/.zcompdump` が起動のたびに書き換わるなら、`compinit` が 2 回走っていないか。
  `enableGlobalCompInit` を戻さない。home-manager 側を止める形にしない理由)。`README.md` の「利用側が与えるもの」に
  1 行 (core の前提: 補完の初期化は home-manager の `~/.zshrc` が行う。利用側が与えるもの: home-manager の darwin
  モジュールの読み込み (既存の行と同じ) と、home-manager を使わないアカウントの対話 zsh には補完の初期化が無いことの
  承知)。`docs/CONSUMER-GUIDE.md` は 1 節「家の前提」の「nix-darwin + home-manager」の項に、家の形としてこの前提を
  足し、仕組みの説明は README へのリンクで指す (手引きは core の文書と重ねない。読み手への指示は書かない)。
  `docs/GUIDE.md` (キーとコマンドの早見表) には書かない。
- **D6. `brew shellenv` の `FPATH` は観察として記録し、直さない。** 直接の引き金ではあるが、直す案 (export を外す、
  `brew shellenv` を `compinit` より前に動かす) はそれぞれ Homebrew の補完の見え方を変える別の change になる。
  この change の後に残る影響は「シェルから起動したシェルの `fpath` に重複がある」だけで、`compinit` が 1 回なら
  作り直しは起きない。

## Risks / Trade-offs

- [home-manager を使わないアカウント (別の macOS ユーザー) の対話 zsh で補完が初期化されない] → core の darwin
  モジュールは home-manager の読み込みをすでに前提にしている。前提として README と手引きに書く (D5)。root の
  ログインシェルは `/bin/sh` なので対象外。
- [home-manager が `enableCompletion` の既定や `compinit` の順序を変える] → `~/.zshrc` の `compinit` が無くなると
  補完が消えて zoxide / fzf の初期化が落ちるので、lock の更新の PR で気づける。D4 (5) の確認を lock の更新の手順にも
  書く必要は無い (落ちれば対話シェルで即座に分かる)。
- [nix-darwin が `enableGlobalCompInit` を改名・廃止する] → 評価が止まるので CI と lock の更新で気づく。
- [別の利用側の症状の引き金が家と違う (例: `~/.zshrc` の中で `fpath` に足すものがある)] → どの引き金でも
  「2 回の `compinit` が違う個数を見る」ことが作り直しの条件なので、1 回にすれば消える。利用側では、直す前と後で
  `~/.zcompdump` の更新時刻と起動時間を見れば同じ原因かが分かる (手引きには書かない。利用側の判断)。
- [`bashcompinit` が `compinit` 無しで警告を出す] → D2 の確認で拾い、出るなら `enableBashCompletion = false` を足す。

## Migration Plan

1. core: この change を 1 コミット (モジュール + コメント + CLAUDE.md + README) と、手引きの 1 コミットで PR にする。
   マージの前に、利用側 (家) で `--override-input core path:../dotfiles` の build を通し、D4 (1)(2) を確かめる。
2. 利用側 (家): `nix flake update core` を PR にして、両方の Mac で switch する。switch の後に D4 (3)(4)(5) を確かめる。
   家の CI の手引きのレビューは、手引きの 1 節の追記を読んで「影響なし」になるはず。
3. ほかの利用側: lock を上げて switch する。それまでは自分の darwin モジュールに同じ宣言を置いてよい (D3)。
4. 戻すとき: 宣言を外す (`/etc/zshrc` に `compinit` が戻る)。dump は `compinit` が作り直すので手作業は要らない。

## Open Questions

(なし)
