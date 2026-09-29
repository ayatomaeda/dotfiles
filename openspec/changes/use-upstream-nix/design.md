## Context

core の `modules/darwin/default.nix` は `nix.enable = false` で nix-darwin の Nix の管理を止め、Nix の本体と設定を
Determinate Nix に任せている。CI (`ci.yml`、`update-flake-lock.yml`) も `DeterminateSystems/determinate-nix-action` で
Nix を入れ、lock の更新は `DeterminateSystems/update-flake-lock` が行う。所有者は upstream の Nix を使うと決めた。

調査で分かったこと (2026-09-30。所有者の Mac と、利用側の lock が固定した nix-darwin / nixpkgs / home-manager で確認):

- `nix.enable = true` にすると、`environment.etc` に `nix/nix.conf` と `nix/registry.json`、`launchd.daemons` に
  `nix-daemon` が増える。ほかに消えるものも増えるものも無い。Nix の本体は lock の nixpkgs の `nix` (2.34 系) で、
  `environment.systemPackages` に `nix` と `nix-info` が入る。`experimental-features` は設定されない。
- registry の `nixpkgs` は、nix-darwin の `nixpkgs.flake.source` (`darwinSystem` の既定) によって lock の nixpkgs の
  store パスに固定される (`type = "path"`)。path 型なので rev と日付を持たず、`nixpkgs#lib.version` は lock から
  評価した値と一致しない。一致を見るなら narHash を比べる。
- home-manager の darwin 統合は、OS の `nix.enable` のとき OS の `nix.package` を home-manager に渡す。そのため
  `home.activationPackage` の drvPath は変わる (activation の PATH に `nix` が入る)。`home-files` と `home.path` は
  変わらない。
- nix-darwin は `nix.enable = true` のとき、`/usr/local/bin/determinate-nixd` があると activation を止める。
  `darwin-rebuild switch` は activation の前に system のプロファイルへ世代を足すので、止まっても世代は残り、
  再起動すると `/run/current-system` がその世代を指す。
- 利用側の Mac のホストに `nix.enable = lib.mkForce false` を与えると、toplevel の drvPath は今の構成と一致する。
- 起動時の `/nix` のマウントは `determinate-nixd init` の launchd が行っている。nix-darwin はマウントを管理しないので、
  ストアを残したまま daemon だけ替えることはできず、入れ直しになる。
- Determinate のアンインストーラ (と upstream のインストーラ) は、`darwin-rebuild` か `darwin-option` が PATH にあるか、
  `org.nixos.activate-system` が launchd に載っていると、「nix-darwin を先に消せ」として削除を拒否する。
- アンインストーラは `/nix` のボリュームを強制的にアンマウントする。`/nix/store` から動いているプロセス (tmux、
  herdr、home-manager の zsh の設定から起動したもの) と、home-manager が張ったリンク (`~/.zshrc`、`~/.ssh/config`、
  git の設定) は、入れ直して switch するまで使えない。
- `darwin-uninstaller` は `/etc` の nix-darwin のリンクを消して `.before-nix-darwin` を戻し、nix-darwin の launchd を
  外す。Homebrew とユーザーには触れない。sshd の `100-nix-darwin.conf` も消えるので、sshd は macOS の既定
  (パスワード認証を受け付ける) に戻る。
- upstream の `nix flake check` (2.34) は `darwinConfigurations` を評価しない。存在しない option を書いた構成でも
  `all checks passed!` で終わる。ci.yml の後段の全ホストの評価は、upstream でも壊れた構成を検出して失敗した。
- NixOS の実験版インストーラ (`artifacts.nixos.org/nix-installer`) は `--enable-flakes` で flakes を有効にし、
  `/nix/nix-installer uninstall` で消せる。nix-darwin は、このインストーラの 2.33.3 が `--enable-flakes` で書く
  `nix.conf` と、Nix 2.33.3 の `nix.custom.conf` のハッシュを既知のものとして持つ。ビルド用のユーザー
  (GID 350、UID 351 から) は nix-darwin の期待と一致する。インストーラの `org.nixos.nix-daemon.plist` は、
  nix-darwin の launchd の activation が内容を比べて置き換える。
- `cachix/install-nix-action` は `releases.nixos.org` の公式のインストーラを使い、`experimental-features =
  nix-command flakes` を書く。
- 自動の lock 更新の PR は GitHub App の token で作られ、ブランチ `update_flake_lock_action` で開いている。

## Goals / Non-Goals

**Goals:**

- core と CI から Determinate Nix と Determinate Systems の action への依存を無くす。
- nix-darwin に Nix の設定と daemon を管理させ、flake で適用できる状態を宣言だけで作る。
- 各 Mac を入れ替える手順を、少ない手数で、止まる箇所を先に示して書く。

**Non-Goals:**

- 利用側のリポジトリ (workflow、導入手順、spec) の変更。この change の後に同じ方針で行う。
- GC、`auto-optimise-store`、substituter、`trusted-users`、`ssl-cert-file` を core で決めること。既定のままにする。
  独自の CA が要る利用側は、利用側で `nix.settings` を与える。
- Lix など、ほかの Nix の実装への対応。
- 入れ替えの作業中に機能を保つこと。所有者は、作業中に一時的に機能が止まってよいとした。止まるのは次のもの:
  nix-darwin が宣言した sshd の設定 (公開鍵認証だけを受け付ける。作業中はパスワード認証を受け付け、remote-access の
  要件を一時的に満たさない)、Touch ID の sudo、home-manager の設定 (シェル、ssh、git)、`/nix/store` から動くもの。

## Decisions

### D1. `nix.enable` を既定 (true) に戻し、flakes を core で有効にする

`nix.enable = false` の行を消し、`nix.settings.experimental-features = [ "nix-command" "flakes" ]` を置く。
インストーラも `nix.conf` に flakes を書くが、nix-darwin が `nix.conf` を置き換えるので、宣言が無ければ switch の後に
flakes が消える。どの利用側も flake で構成を適用するので、core に置く。値は定数なので option にしない。

「その Mac の Nix は Determinate ではないこと」は利用側が与える前提になる。CLAUDE.md の決まりに従い、
`modules/darwin/default.nix` のコメントに約束として書く。

- 代案: `nix.enable` を option にして利用側に選ばせる。Determinate を前提にしない決定に反し、どの利用側も同じ値を
  与えるので採らない。

### D2. channel を無効にする (`nix.channel.enable = false`)

構成は flake だけで扱う。既定 (true) は `NIX_PATH` に root の channels のディレクトリを足すが、入れ直した Mac には
channel が無い。無効にすると `NIX_PATH` は `nixpkgs=flake:nixpkgs` だけになり、registry で lock の nixpkgs に解決される。
`nix-channel` は PATH から消える。`darwinSystem` は `system.checks.verifyNixPath` を切るので、channel の検査にも
当たらない。

- 代案: 既定のまま。存在しないパスを `NIX_PATH` に残すだけなので採らない。

### D3. 所有者の Mac のインストーラは NixOS の実験版インストーラを `--enable-flakes` だけで使う

`curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes`。NixOS のコミュニティが
保守する公式のインストーラ (状態は Beta) で、アンインストーラとレシートを持つ。`--extra-conf` などで `nix.conf` の
中身を変えると、nix-darwin の既知のハッシュと一致せず初回の switch が止まるので、ほかのフラグは付けない。
既知のハッシュは 2.33.3 のものなので、インストーラの版によっては一致しない (Risks)。

- 代案: nixos.org のダウンロードページが案内する従来のスクリプト (`nixos.org/nix/install`)。案内の度合いは上だが、
  消すときの手順が手作業になる。所有者は実験版を選んだ。

### D4. 入れ替えは `darwin-uninstaller` → Determinate の uninstall → 入れ直し → 初回の構築

Determinate のアンインストーラは nix-darwin が入っていると削除を拒否するので、先に `sudo darwin-uninstaller` で
nix-darwin を外す。これで `/etc` も macOS の状態に戻る。次に `sudo /nix/nix-installer uninstall`、新しいターミナルで
インストーラ、利用側のリポジトリで初回の構築を行う。`darwin-rebuild` は `/nix` とともに消えているので、
`nix build .#darwinConfigurations.<host>.system` → `sudo ./result/sw/bin/darwin-rebuild switch --flake .#<host>` を
使う (CLAUDE.md の初回の手順と同じ)。

作業は Terminal.app の素の `/bin/zsh` で、tmux と herdr の外で行う。アンマウントで `/nix/store` から動くものが落ち、
home-manager の設定が切れるため。接続先の Mac は、その Mac の前で行うか、herdr を通さない ssh で行う。
git の設定も切れるので、コミットは switch の後に行う。

- 代案: Determinate の uninstall から始める。アンインストーラが拒否するので成り立たない。

### D5. lock の更新は、入れ替えの前に利用側のコミットとして用意する

CLAUDE.md の「利用側のコミットから switch する」に従う。

1. この change をマージした後、利用側で core だけを上げる PR (`nix flake update core`) を作り、CI を通す。
2. 所有者がすべての Mac を入れ替えられる時期にその PR をマージする。各 Mac はマージしたコミットを pull してから
   D4 の手順を行う。
3. 入れ替えていない Mac では switch しない。誤って switch して止まったら、再起動の前に
   `sudo /run/current-system/sw/bin/darwin-rebuild --rollback` で世代を戻す。1 台ずつ移す期間が長くなるなら、
   残る Mac のホストに一時的に `nix.enable = lib.mkForce false` を与える (drvPath は今の構成と一致する)。

利用側の週次の lock 更新の PR は core も上げる。この change をマージした後、入れ替えの前にその PR をマージしない。

### D6. CI の Nix は `cachix/install-nix-action`

NixOS の公式リリースを入れ、flakes を有効にする定番の action。`determinate-nix-action` を置き換える。FlakeHub と
通信しないので、`update-flake-lock.yml` の `id-token: write` も消す。

### D7. lock の更新は `nix flake update --commit-lock-file` と `gh` で行う

`DeterminateSystems/update-flake-lock` の代わりに、workflow の中で次を行う。

1. token を選ぶステップ (GitHub App → `FLAKE_LOCK_TOKEN` → `GITHUB_TOKEN`) を checkout より前に置き、選んだ token を
   checkout に渡す。checkout は token を git の設定に残すので、push も PR の操作も同じ token で行われる。
   `GITHUB_TOKEN` で push すると、その push では ci.yml が走らない。
2. git の author を `github-actions[bot]` にして `nix flake update --commit-lock-file` を実行する。入力ごとの変更は
   コミットの本文に入る (標準出力には何も出ない)。
3. 固定のブランチ `update_flake_lock_action` がリモートにあれば、その `flake.lock` と比べる。無ければ main と比べる。
   同じなら終わる。上流が動かなかった週に PR を更新しない。
4. そのブランチへ force push する。
5. ブランチの PR が開いていなければ `gh pr create` で作る (タイトル `chore: nix flake update`、ラベル
   `dependencies` と `automated`、本文はコミットの本文)。開いていれば `gh pr edit --body` で本文を新しい変更に替える。

token の優先順位と、`GITHUB_TOKEN` を使う場合の制約の説明は今のまま残す。ラベルが消されると `gh pr create` が
失敗することをコメントに書く。

- 代案: `peter-evans/create-pull-request`。手順は短くなるが、第三者の action を 1 つ足すことになる。`gh` は runner に
  入っており、必要な処理は数行で書ける。

### D8. CI のコメントを upstream の実測に合わせる

`ci.yml` の「Determinate Nix の flake check は darwinConfigurations も評価対象に含める」と、`nix flake show --json` の
形についての記述を、upstream の振る舞い (評価しない、`{"type":"unknown"}`) に書き換える。後段の全ホストの評価が
構成を評価する唯一のステップであることを明記する。

### D9. 文書

- 入れ替えの手順は README の「`darwin-rebuild` について」の近くに置く。一度きりの作業で、`docs/GUIDE.md` の
  「早見表と、設定を変えるときに書く場所」には合わない。止まる機能、戻れないこと、作業する端末の条件を手順の前に
  書く。ホストは役割の名前で書く。
- README の `darwinModules.default` の説明から「Nix の管理の無効化 (Determinate Nix 前提)」を除き、Nix の設定を
  nix-darwin が管理する旨にする。「利用側が与えるもの」に、Determinate ではない Nix が入っていることを足す。
- CLAUDE.md の「`nix search nixpkgs` は `flake.lock` を見ていない」を削る。「`darwin-rebuild` は呼び出し側の PATH に
  依存しない」の項は、`nix` が `nix.package` の store パスから解決され、`/nix/var/nix/profiles/default/bin` は
  予備になったことに合わせて書き直す。

## Risks / Trade-offs

- [入れ替えで `/nix` が消え、前の世代に戻れない] → 手順の冒頭に書く。入れ替え直後の構成は、それまでの構成と
  core 以外は同じ。
- [作業中は sshd がパスワード認証を受け付け、公開鍵認証 (nix-darwin の authorized keys) は効かない] → 手順の冒頭に
  書く。信頼できるネットワークで行う。接続先の Mac を ssh 越しに行うときは、既存の接続を閉じずに、uninstaller の
  後で別の接続からパスワードでログインできることを確かめてから先へ進む。その Mac の前で行うときは、作業中は
  リモートログインを切ってもよい。
- [インストーラの版が 2.33.3 でなく、`nix.conf` のハッシュが nix-darwin の既知のものと一致せず、初回の switch が
  止まる] → 案内どおり `/etc/nix/nix.conf` を `.before-nix-darwin` に退避して再実行する。`/etc/zshrc` などで
  止まったときも同じ。`/etc/nix/nix.custom.conf` で止まったときは (`custom settings … aborting activation`)、
  中身が空であることを確かめて消す。中身があれば `nix.settings` に移してから消す。
- [インストーラの Nix (2.35 系) と、switch 後の daemon (lock の 2.34 系) の版がずれる] → store の schema の版は
  同じ。switch の後に `nix store info` と build が通ることを確かめる。
- [評価が遅くなる (lazy-trees と並列評価が無くなる)] → 受け入れる。
- [Determinate が残る Mac で switch すると、activation は止まるが世代は残る] → D5 の rollback を手順に書く。
- [実験版インストーラは Beta] → 問題が出たら従来のスクリプトに切り替えられる。nix-darwin から見た違いは
  `nix.conf` の中身だけ。
- [アンインストールの直後に、再起動なしで入れ直せるかは未確認] → 1 台目で確かめ、必要なら手順に再起動を足す。

## Migration Plan

1. この change をマージする。`update-flake-lock.yml` を `workflow_dispatch` で 1 回実行し、開いている自動 PR が
   更新されてその PR で ci.yml が走り、本文が替わること (差分が無ければ何もせず終わること) を確かめる。
2. 利用側で core を上げる PR を作り、CI を通す (D5)。
3. 所有者の手元の Mac で PR をマージし、そのコミットから D4 の手順で入れ替える。止まった箇所と対処を記録し、
   手順に反映する (README を直す別の変更として扱う)。
4. 接続先の Mac で同じコミットを pull し、同じ手順で入れ替える。
5. 各 Mac で、spec の scenario (flakes の有効化、nixpkgs の narHash の一致、Determinate の daemon とバイナリの不在) を
   確かめる。
6. 利用側のリポジトリの workflow と導入手順を、別の変更で直す。

ロールバック: 入れ替えた Mac を Determinate Nix に戻すには、`darwin-uninstaller` → `/nix/nix-installer uninstall` →
Determinate のインストーラで入れ直し、利用側の lock を core のこの change の前のコミットに戻したコミットから
初回の構築を行う。
