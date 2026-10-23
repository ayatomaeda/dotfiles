# Tasks

## 1. 補完の dump の鍵を固定する (1 コミット: `fix(zsh): 補完の dump を起動の仕方に依らず作り直させない (single-zsh-compinit)`)

- [x] 1.1 `modules/darwin/default.nix` に `programs.zsh.enableGlobalCompInit = false;` を、理由のコメント (2 回の `compinit`
      が別々の fpath を見ること、home-manager 側を残す理由、`enable` / `enableCompletion` を触らない理由、home-manager を
      使わないアカウントには補完の初期化が無い前提。design D1、D2) 付きで足す。`nix flake check --no-build` が通り、
      `nix eval --raw '.#darwinConfigurations.example.config.environment.etc.zshrc.text'` の出力に `compinit` の行が無く
      `bashcompinit` の行が残っていることで確かめる
- [x] 1.2 `modules/common/zsh.nix` の darwin の `initContent` (`brew shellenv` と `PATH` の並べ直し) を `lib.mkOrder 550` に
      し、`compinit` より前、home-manager の fpath の組み立てより後に置く理由をコメントに書く (design D3)。`FPATH` の
      export には手を加えない。`programs.zsh.completionInit` を `autoload -U compinit && compinit -d
      "${ZDOTDIR:-$HOME}/.zcompdump-$ZSH_VERSION"` にし、版ごとにする理由をコメントに書く (design D4)。`nix flake check
      --no-build` が通り、例の構成の `home-manager.users.<user>.programs.zsh.initContent` を評価して、`typeset -U`、
      `brew shellenv`、`compinit -d` がこの順で並ぶことで確かめる
- [x] 1.3 利用側 (家) のクローンで `--override-input core path:../dotfiles` の build を通し、生成物の差を確かめる (design D5
      (1)(2)): build の `etc/zshrc` と `/etc/zshrc` の差が `compinit` の 1 行だけ。home-manager の `home-files` の木の差が
      `.zshrc` だけで、その差が Homebrew の行の移動と `compinit` の `-d` だけ。`result` は終わったら消す (GC ルートを残さない)
- [x] 1.4 1.3 の `etc/zshrc` と `.zshrc` を作業用のディレクトリに置き、`NOSYSZSHRC=1` と `ZDOTDIR` で読ませて、spec の
      Scenario「混ぜる」「補完が使える」「`/etc/zshrc` の `compinit` に頼らない」を通す (design D5 (3))。dump の置き場所は
      作業用のディレクトリに向け、ホームディレクトリに書かない。合格の条件: 2 巡目の 8 回の起動で dump の更新時刻が
      変わらない、1 つのシェルの起動が 0.15 s 程度、`_rg` `_brew` `_git` `compdef` が関数、標準エラー出力に補完の警告が無い
- [x] 1.5 `CLAUDE.md` の「踏むと痛い箇所」に 1 項を足す (design D6): 症状 (シェルから起動したシェルの起動が重い、dump が
      書き換わる)、原因 (dump の鍵の揺れの 3 つの元)、外さない 3 つの宣言、lock の更新で home-manager が上がったら生成された
      `~/.zshrc` の並び (`typeset -U`、`brew shellenv`、`compinit`) を見ること、確かめ方。既存の項と同じ文体で書き、
      `rg -n 'zcompdump' CLAUDE.md` が 1 項の中だけで当たることで確かめる
- [x] 1.6 `README.md` の「利用側が与えるもの」の表に 1 行を足す (design D6)。表の列が崩れていないことを描画で確かめる
- [x] 1.7 所有者の端末で `<家の構成のクローン>/scripts/check-core.sh ../dotfiles` が 0 で終わることを確かめる。当たったら
      語の一覧を変えず、文章を役割の名前で書き直す

## 2. 手引きを直す (1 コミット: `docs: 手引きの前提に補完の初期化の置き場所を足す (single-zsh-compinit)`)

- [x] 2.1 `docs/CONSUMER-GUIDE.md` の 1 節「家の前提」の「nix-darwin + home-manager」の項に、家の形 (Mac は 1 ユーザーで、
      そのユーザーが home-manager を使う) と、core が補完の初期化を home-manager の `~/.zshrc` だけに任せるので
      home-manager を使わないアカウントの対話 zsh には補完の初期化が無いことを書き、仕組みは `README.md` の「利用側が
      与えるもの」へのリンクで指す (design D6)。読み手への指示を書かないこと、`rg -n 'compinit|補完の初期化'
      docs/CONSUMER-GUIDE.md` の当たりが 1 節の中だけであることで確かめる
- [x] 2.2 2.1 の記述を家の構成 (ユーザーの数、home-manager の darwin モジュールの読み込み) と突き合わせ、冒頭の
      `最終照合:` をその日に改める (design D6)。`rg -n '^最終照合: [0-9]{4}-[0-9]{2}-[0-9]{2}$' docs/CONSUMER-GUIDE.md` が
      1 件だけ当たること
- [x] 2.3 手引きのリンクをすべて抽出し (`rg -o '\]\([^)]+\)' docs/CONSUMER-GUIDE.md`)、足したリンクのアンカーが `README.md`
      の見出しと一致することを確かめる
- [x] 2.4 1.7 と同じ検査を通す。コミットメッセージと branch 名も通す (`git log --format=%B main..HEAD |
      <家の構成のクローン>/scripts/check-core.sh -`、`git branch --show-current | <家の構成のクローン>/scripts/check-core.sh
      --names`)。どちらも 0 であること

## 3. archive と PR

- [x] 3.1 `openspec validate single-zsh-compinit --strict` が通ることを確かめ、`openspec archive single-zsh-compinit` で
      `openspec/specs/terminal-tooling/spec.md` に delta を反映する。反映後の spec に要件が 1 つ増え、既存の要件が変わって
      いないことを `git diff --stat` と `rg -n '^### Requirement' openspec/specs/terminal-tooling/spec.md` で確かめる
      (1 コミット: `docs: single-zsh-compinit を archive して specs に反映する`)
- [ ] 3.2 PR の本文を書き、`<家の構成のクローン>/scripts/check-core.sh -` に通して 0 であることを確かめてから PR を出す。
      本文に利用側の構成の名前と、利用側のコミットのハッシュを書かない
- [ ] 3.3 レビューを受けてマージする。利用側 (家) の lock の更新と switch、switch の後の確認 (spec の Scenario「混ぜる」
      「補完が使える」を本物のシェルで通す。switch の前から動いている herdr / tmux のサーバーは起動し直す) は家の PR で行う
      (design Migration Plan 2)
