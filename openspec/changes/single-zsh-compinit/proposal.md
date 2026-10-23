# Proposal

## Why

core の darwin モジュールと home モジュールを対で使うと、対話 zsh の起動で補完の初期化 (`compinit`) が 2 回走る。
nix-darwin が `/etc/zshrc` に置くもの (`programs.zsh.enableGlobalCompInit` の既定) と、home-manager が `~/.zshrc` に
置くもの (`programs.zsh.enableCompletion` の既定) で、core も利用側もどちらにも触れていない。2 つの `compinit` は
別々の `fpath` で走るので、見える補完ファイルの個数が食い違うと互いに `~/.zcompdump` を無効にし合い、**起動のたびに
dump を 2 回作り直す**。所有者の端末では、シェルから起動したシェル (マルチプレクサのペイン、エージェントのシェル) が
この条件に当たり、起動が 1.35 秒かかっていた (`/etc/zshrc` の `compinit` を飛ばすと 0.17 秒。dump の書き換えも止まる)。
別の利用側でも同じ症状 (端末の起動が重い) が報告されたので、個別に回避させず core で止める。

## What Changes

- **core の `modules/darwin/default.nix` で nix-darwin の `programs.zsh.enableGlobalCompInit = false` を宣言する。**
  `/etc/zshrc` から `compinit` の行だけが消え、補完の初期化は home-manager の `~/.zshrc` の 1 回になる。
  `programs.zsh.enable` と `enableCompletion` は既定のまま残す (`/etc/zshenv` の Nix の環境設定、`fpath`、
  `nix-zsh-completions` は保たれる)。
- **止めるのは nix-darwin 側で、home-manager 側ではない。** home-manager の `compinit` は、`fpath` を整理した後、
  `compdef` を使う初期化 (fzf、zoxide) の前に置かれ、nix-darwin の無い環境 (standalone の home-manager) でも
  同じ `~/.zshrc` で動く。nix-darwin 側に寄せると `modules/common` の補完が darwin 専用のファイルに依存する。
- `drvPath` は意図的に変わる (`/etc/zshrc` の生成物が変わる)。確認は実体で行う: `/etc/zshrc` の差分が `compinit` の
  1 行だけであること、シェルから起動したシェルで `~/.zcompdump` が書き換わらないこと、起動時間、補完と `compdef` が
  動くこと。
- **文書**: core の `CLAUDE.md` の「踏むと痛い箇所」と `README.md` の「利用側が与えるもの」に、補完の初期化が
  home-manager の 1 回だけであることと、その前提 (home-manager を使わないアカウントの対話 zsh には補完の初期化が
  無い) を書く。`docs/CONSUMER-GUIDE.md` の 1 節「家の前提」に同じ前提を家の形として書き、`最終照合:` を改める。
- 範囲に入れないもの: `brew shellenv` が `FPATH` を export することで、シェルから起動したシェルの `/etc/zshenv` が
  同じディレクトリを二重に積む件 (個数の食い違いの直接の引き金だが、`compinit` が 1 回になれば個数の比較は
  `~/.zshrc` の中で閉じるので症状は消える。`fpath` の重複そのものの整理は別件)。利用側のリポジトリの変更
  (lock の更新、利用側の darwin モジュールに同じ宣言を置いてしのぐこと)。

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `terminal-tooling`: 対話 zsh の補完の初期化は、利用側が与える home-manager の構成の 1 回だけで行い、nix-darwin の
  全ユーザー向けの `compinit` を core の darwin モジュールが止める、という要件を足す (ADDED)。

## Impact

- **コード:** `modules/darwin/default.nix` (1 つの option とコメント)。`modules/common/zsh.nix` は変えない。
- **生成物:** `/etc/zshrc` (`compinit` の 1 行が消える)。`~/.zshrc` は変わらない。`drvPath` は変わる。
- **文書:** `CLAUDE.md` (踏むと痛い箇所)、`README.md` (利用側が与えるもの)、`docs/CONSUMER-GUIDE.md` (1 節と
  `最終照合:`)。
- **利用側:** core の lock を上げて switch すると入る。core の darwin モジュールだけを使って home-manager を使わない
  アカウントの対話 zsh では、補完が初期化されなくなる (core の darwin モジュールは home-manager の darwin モジュールの
  読み込みをもう前提にしているので、新しい前提ではない)。lock を上げるまで、利用側の darwin モジュールに同じ
  `enableGlobalCompInit = false` を置いても、同じ値の bool の重複はモジュールシステムが受け入れる (実測)。
