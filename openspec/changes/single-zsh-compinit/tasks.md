# Tasks

## 1. nix-darwin の `compinit` を止める (1 コミット: `fix(zsh): 補完の初期化を home-manager の 1 回にする (single-zsh-compinit)`)

- [ ] 1.1 `modules/darwin/default.nix` に `programs.zsh.enableGlobalCompInit = false;` を、理由のコメント (2 回の `compinit` が
      別々の `fpath` で走って dump を作り直し合うこと、home-manager 側を残す理由、`enable` / `enableCompletion` を触らない
      理由、home-manager を使わないアカウントには補完の初期化が無い前提。design D1、D2) 付きで足す。`nix flake check
      --no-build` と `nix eval --raw '.#darwinConfigurations.example.config.environment.etc.zshrc.text'` が通り、後者の
      出力に `compinit` が無く `bashcompinit` が残っていることで確かめる
- [ ] 1.2 利用側 (家) のクローンで、変更前の `/etc/zshrc` との差を確かめる (design D4 (1)): `nix eval --raw --override-input core
      path:../dotfiles '.#darwinConfigurations.<host>.config.environment.etc.zshrc.text' | diff /etc/zshrc -` の差分が
      `autoload -U compinit && compinit` の 1 行だけであること
- [ ] 1.3 利用側 (家) のクローンで `darwin-rebuild build --flake .#<host> --override-input core path:../dotfiles` を通し、
      生成物の差が `/etc/zshrc` の 1 行だけであることを確かめる (design D4 (2)): `diff /etc/zshrc result/etc/zshrc` が 1.2 と
      同じ 1 行で、home-manager の世代 (`nix build --override-input core path:../dotfiles
      '.#darwinConfigurations.<host>.config.home-manager.users.<user>.home.activationPackage'`) の `result/home-files/.zshrc`
      と現行の `~/.zshrc` の `diff` が空であること。`result` は終わったら消す (GC ルートを残さない)
- [ ] 1.4 switch の前に模擬で効果を確かめる (design の Context の模擬と同じ): 1.2 の出力をファイルに置き、`ZDOTDIR` の
      `.zshrc` でそれと `~/.zshrc` を順に読む対話シェルを `NOSYSZSHRC=1` で 3 回起動し、2 回目以降の起動が 0.3 秒未満で、
      `~/.zcompdump` の更新時刻が変わらないこと。あわせて `bashcompinit` が `compinit` 無しで警告を出さないこと
      (design D2。出るなら `enableBashCompletion = false` を足して 1.1 からやり直す)
- [ ] 1.5 `CLAUDE.md` の「踏むと痛い箇所」に 1 項を足す (design D5): 症状 (シェルから起動したシェルの起動が 1 秒以上、
      `~/.zcompdump` が起動のたびに書き換わる)、原因 (2 つの `compinit` が違う個数を見る)、`enableGlobalCompInit` を
      戻さないこと、home-manager 側を止める形にしない理由、`brew shellenv` の `FPATH` の export が引き金で `fpath` の重複は
      残ること (design D6)。既存の項と同じ文体 (太字の見出し文 + 本文) で書き、`rg -n 'compinit' CLAUDE.md` で 1 項だけ
      当たることで確かめる
- [ ] 1.6 `README.md` の「利用側が与えるもの」の表に 1 行を足す (design D5): core の前提「対話 zsh の補完の初期化は
      home-manager の `~/.zshrc` が行う (`darwinModules.default` が nix-darwin の全ユーザー向けの `compinit` を止める)」、
      利用側が与えるもの「home-manager の darwin モジュールの読み込み。home-manager を使わないアカウントの対話 zsh には
      補完の初期化が無い」。表の列が崩れていないことを `rg -n 'compinit' README.md` と表の描画で確かめる
- [ ] 1.7 所有者の端末で `<家の構成のクローン>/scripts/check-core.sh ../dotfiles` が 0 で終わることを確かめる。当たったら
      語の一覧を変えず、文章を役割の名前で書き直す

## 2. 手引きを直す (1 コミット: `docs: 手引きの前提に補完の初期化の置き場所を足す (single-zsh-compinit)`)

- [ ] 2.1 `docs/CONSUMER-GUIDE.md` の 1 節「家の前提」の「nix-darwin + home-manager」の項に、家の形として「対話 zsh の
      補完の初期化は home-manager の `~/.zshrc` の 1 回だけ。core の darwin モジュールが nix-darwin の `compinit` を
      止めるので、home-manager を使わないアカウントの対話 zsh には補完の初期化が無い」を足し、仕組みは `README.md` の
      「利用側が与えるもの」へのリンクで指す (design D5)。読み手への指示 (「〜せよ」「〜を確かめよ」) を書かないこと、
      `rg -n 'compinit' docs/CONSUMER-GUIDE.md` の当たりが 1 節の中だけであることで確かめる
- [ ] 2.2 手引きの冒頭の `最終照合:` を、家の構成と突き合わせた日 (この change を apply した日) に改める。
      `rg -n '^最終照合: [0-9]{4}-[0-9]{2}-[0-9]{2}$' docs/CONSUMER-GUIDE.md` が 1 件だけ当たること
- [ ] 2.3 手引きのリンクをすべて抽出し (`rg -o '\]\([^)]+\)' docs/CONSUMER-GUIDE.md`)、足したリンクの見出しが `README.md`
      に在ること (アンカーの文字列が見出しと一致すること) を確かめる
- [ ] 2.4 1.7 と同じ検査を手引きにも通す。コミットメッセージとブランチ名も通す (`git log --format=%B main..HEAD |
      <家の構成のクローン>/scripts/check-core.sh -`、`git branch --show-current | <家の構成のクローン>/scripts/check-core.sh
      --names`)。どちらも 0 であること

## 3. archive と PR

- [ ] 3.1 `openspec validate single-zsh-compinit --strict` が通ることを確かめ、`openspec archive single-zsh-compinit` で
      `openspec/specs/terminal-tooling/spec.md` に delta を反映する。反映後の spec に新しい要件が 1 つ増え、既存の要件が
      変わっていないことを `git diff --stat` と `rg -n '^### Requirement' openspec/specs/terminal-tooling/spec.md` で
      確かめる (1 コミット: `docs: single-zsh-compinit を archive して specs に反映する`)
- [ ] 3.2 PR の本文を書き、`<家の構成のクローン>/scripts/check-core.sh -` に通して 0 であることを確かめてから PR を出す。
      本文に利用側の構成の名前と、利用側のコミットのハッシュを書かない
- [ ] 3.3 レビューを受けてマージする。利用側 (家) の lock の更新と switch、switch の後の確認 (design D4 (3)(4)(5):
      シェルから起動したシェルを 2 回起動して `~/.zcompdump` の更新時刻が変わらない、起動が 0.3 秒未満、`whence -w _rg` が
      function、`NOSYSZSHRC=1 zsh -ic exit` が `compdef` のエラーを出さない) は家の PR で行う (design Migration Plan 2)
