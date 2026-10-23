# Proposal

## Why

core の darwin モジュールと home モジュールを対で使うと、対話 zsh の起動が補完の dump の作り直しで重くなる。所有者の
端末では、シェルから起動したシェル (マルチプレクサのペイン、エージェントのシェル) が 1 秒以上かかっていた。別の利用側
でも同じ症状 (端末の起動が重い) が報告されている。nix-darwin と home-manager の併用者、`brew shellenv` の利用者の
あいだでも、同じ型の報告と修正が 2026 年に複数ある (design の Context)。

dump は `compinit` が「zsh の版」と「fpath に見える補完ファイルの個数」を鍵にして持つ cache で、鍵が違えば作り直す。
いまの構成では、起動の仕方によって鍵が揺れる。揺れの元は 3 つで、どれも core と利用側が宣言していない既定値と、
宣言の順序から来ている。

1. `compinit` が 2 回走る。nix-darwin の `/etc/zshrc` (`enableGlobalCompInit` の既定) と home-manager の `~/.zshrc`
   (`enableCompletion` の既定) で、2 回は別々の fpath を見る。
2. Homebrew の補完が `compinit` の後で fpath に入る。core は `brew shellenv` を `compinit` の後に置いているので、端末の
   アプリが起動したシェルの dump には Homebrew の補完が入らず、そのシェルから起動したシェル (export された `FPATH` で
   受け継ぐ) の dump には入る。
3. 2 つの zsh が 1 つの dump を奪い合う。対話シェルは macOS の `/bin/zsh` (ログインシェル) で、`PATH` の `zsh` は Nix の
   zsh。版が違うので、片方を起動するたびにもう片方の dump が捨てられる。

## What Changes

- **`compinit` を home-manager の `~/.zshrc` の 1 回にする。** core の `modules/darwin/default.nix` で
  `programs.zsh.enableGlobalCompInit = false`。`enable` と `enableCompletion` は既定のまま。
- **Homebrew の補完を `compinit` の前に fpath へ入れる。** core の `modules/common/zsh.nix` で、`brew shellenv` を
  home-manager の fpath の組み立て (`typeset -U` を含む) の後、`compinit` の前に移す。`brew shellenv` の出力
  (`FPATH` の export を含む) には手を加えない。
- **dump を zsh の版ごとに分ける。** core の `modules/common/zsh.nix` の `programs.zsh.completionInit` で、dump の
  ファイル名に `$ZSH_VERSION` を含める。
- `drvPath` は意図的に変わる。照合は生成物と実体で行う (design D5)。
- **文書**: `CLAUDE.md` の「踏むと痛い箇所」に dump の鍵の項、`README.md` の「利用側が与えるもの」に補完の初期化の
  前提、`docs/CONSUMER-GUIDE.md` の 1 節「家の前提」に家の形。
- 範囲に入れないもの:
  - zsh を 1 つにそろえること (ログインシェルを Nix の zsh にする、`PATH` から Nix の zsh を外す)。design の Non-Goals。
  - 利用側のリポジトリの変更 (lock の更新と switch、lock を上げるまでの利用側の暫定の宣言)。
  - 古い `~/.zcompdump` の削除 (読まれなくなるだけで害は無い)。

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `terminal-tooling`: 対話 zsh の補完の dump が、起動の仕方 (端末のアプリ、シェルからの起動、zsh の版) に依らず
  作り直されない要件を足す (ADDED)。

## Impact

- **コード:** `modules/darwin/default.nix` (1 つの option)、`modules/common/zsh.nix` (`completionInit` と、darwin の
  `initContent` の順序)。
- **生成物:** `/etc/zshrc` (`compinit` の 1 行が消える)。`~/.zshrc` (Homebrew の行が `compinit` の前に移り、`compinit`
  が dump の置き場所を指す)。ほかの `home-files` は変わらない。
- **実体:** dump は `~/.zcompdump-<zsh の版>` になる。
- **文書:** `CLAUDE.md`、`README.md`、`docs/CONSUMER-GUIDE.md`。
- **利用側:** core の lock を上げて switch すると入る。home-manager を使わないアカウントの対話 zsh では補完が初期化されない
  (core の darwin モジュールは home-manager の読み込みをすでに前提にしている)。lock を上げるまで、利用側が自分の darwin
  モジュールに同じ `enableGlobalCompInit = false` を置いても、core が上がった後に同じ値の重複として受け入れられる (実測)。
