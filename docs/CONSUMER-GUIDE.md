# 利用側の構成の手引き

最終照合: 2026-10-19

この文書は、core (このリポジトリ) を flake の input にする**利用側のリポジトリ**の作り方と運用を、所有者の家の
構成 (private) を情報源にして書いたもの。各節は、家で採っている形、その理由 (退けた案や実測で踏んだ失敗)、
それが成り立つ前提の順に並ぶ。読み手の環境でどう合わせるかは書いていない。前提が読み手の環境で成り立つかは
読み手が判断する。core の仕組みそのものの説明は [`README.md`](../README.md)、[`CLAUDE.md`](../CLAUDE.md)、
[`docs/GUIDE.md`](GUIDE.md)、[`openspec/specs/`](../openspec/specs/) にあり、ここではリンクで指す。

冒頭の `最終照合:` の日付は、この文書を家の構成と突き合わせて確かめた日 (編集した日ではない)。これより後の
家の変更はこの文書に入っていないことがある。照合は家の側の仕組みが行い、直すときは core の change として直す。

## 1. 読み手と前提

**読み手** — core のクローンだけが見える端末で、利用側のリポジトリを作って運用する人か、エージェント。家の構成は
private なので読めない。

**家の前提**

- macOS (Apple Silicon)。
- **upstream の Nix** を公式のインストーラで入れる。付けるフラグは `--enable-flakes` だけ。

  ```sh
  $ curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes
  ```

  ほかのフラグ (`--extra-conf` など) を付けると `nix.conf` の中身が変わり、nix-darwin が既知のものと認めず
  switch が止まる。Nix の設定と daemon は nix-darwin が管理する ([`README.md` の「利用側が与えるもの」](../README.md#利用側が与えるもの))。
- nix-darwin + home-manager。home-manager は nix-darwin のモジュールとして読む。
- 1Password の SSH agent が ssh の認証と git の署名の鍵を持つ。
- Homebrew が `/opt/homebrew` にある (cask と App Store アプリの導入に使う)。

**役割** — 編集と非破壊の確認 (評価、`darwin-rebuild build`、dry-run) は利用側で作業する人かエージェント、switch は所有者が行う
([`CLAUDE.md` の「適用のしかた」](../CLAUDE.md#適用のしかた))。

**クローンの配置** — ghq の配置 (`~/git/github.com/<owner>/<repo>`) で、core のクローン (`dotfiles`) を利用側の
クローンの**隣**に置く。隣にあることが、次の 2 つの前提になっている。

- エージェントに core の `CLAUDE.md` を読ませる場合の、利用側の `CLAUDE.md` の 1 行目の読み込み (`@../dotfiles/CLAUDE.md`)
- core の変更を利用側で確かめるときの `--override-input core path:../dotfiles`

core のクローンは構成の build には要らない (input は lock した GitHub の版を読む)。

## 2. リポジトリの形

### ディレクトリ

```
flake.nix                 inputs と darwinConfigurations
hosts/<host>/default.nix  そのホスト固有の差分だけ (家では nixpkgs.hostPlatform だけ)
modules/darwin/
  default.nix             ユーザー、stateVersion、authorized keys、home-manager の配線
  homebrew.nix            Homebrew の方針 (onActivation) と、その環境でだけ使う cask・App Store アプリ
modules/home/
  default.nix             git の identity、署名鍵の項目名、ssh の接続先
  packages.nix            その環境でだけ使う CLI ツール
keys/                     公開鍵 (sshd の authorized keys が読む)
openspec/                 仕様と変更の設計記録
.github/workflows/        CI (全ホストの評価) と flake.lock の週次更新
CLAUDE.md                 エージェントに core の CLAUDE.md を読ませるなら置く (1 行目で読み込み、固有の事情だけを書く)
README.md                 構成と日常の運用
docs/GUIDE.md             利用側に固有のキーとコマンド
```

家にはこのほかに、家でだけ使うモジュールとスクリプトがある (10 節)。

### `flake.nix`

core の [`README.md` の「使い方」](../README.md#使い方)の形。

```nix
{
  inputs = {
    # 再現性は flake.lock が持つので unstable。darwin のパッケージの網羅と鮮度で選んだ。
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = { url = "github:nix-darwin/nix-darwin/master"; inputs.nixpkgs.follows = "nixpkgs"; };
    home-manager = { url = "github:nix-community/home-manager/master"; inputs.nixpkgs.follows = "nixpkgs"; };
    core = {
      url = "github:ayatomaeda/dotfiles";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-darwin.follows = "nix-darwin";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, core }:
    let
      specialArgs = { inherit core; };
    in
    {
      darwinConfigurations.<host> = nix-darwin.lib.darwinSystem {
        inherit specialArgs;
        modules = [
          ./hosts/<host>                         # この中で ../../modules/darwin を import する
          home-manager.darwinModules.home-manager
          core.darwinModules.default
        ];
      };
      # ほかのホストも同じ形で並べる
    };
}
```

- **`core` の 3 つの input を follows でそろえる。** そろえないと nixpkgs を 2 つ取り、core のモジュールが別の版の
  nixpkgs で評価されうる。core の input は core の評価用の例の構成のためのもので、core の `flake.lock` は利用側の
  構成に影響しない。
- `specialArgs` で `core` とスキルの上流を nix-darwin のモジュールへ渡し、`modules/darwin/default.nix` が
  `home-manager.extraSpecialArgs = { inherit anthropic-skills; };` で home のモジュールへ渡す。
- core の README の例との違いは、`modules/darwin` を `flake.nix` に並べず `hosts/<host>` から import していること。
  `flake.nix` の `modules` には、ホスト、home-manager の darwin モジュール、`core.darwinModules.default` の 3 つだけを
  並べる。

### ホスト

`hosts/<host>/default.nix` は差分だけを持つ。

```nix
{ ... }:
{
  imports = [ ../../modules/darwin ];
  nixpkgs.hostPlatform = "aarch64-darwin";
}
```

家のホストは宣言が同一で、`drvPath` も一致する。差が出た時点でホスト側に書く。cask の出し分けのようなホストごとの
層化はしていない (どのホストでも同じものを使うと決めた)。

### ユーザーと `stateVersion`

```nix
# modules/darwin/default.nix
{ core, anthropic-skills, ... }:
let
  username = "<user>";
  # 1 か所で定義する。users.users.*.home と home.homeDirectory が別の場所を指すと、
  # home-manager が別のディレクトリへ配備する。
  homeDirectory = "/Users/${username}";
in
{
  imports = [ ./homebrew.nix ];

  system.primaryUser = username;
  users.users.${username} = {
    name = username;
    home = homeDirectory;
    openssh.authorizedKeys.keyFiles = [ ../../keys/<公開鍵のファイル> ];   # 3 節
  };
  system.stateVersion = <初回の値>;

  home-manager.extraSpecialArgs = { inherit anthropic-skills; };
  home-manager.users.${username} = {
    imports = [ core.homeModules.default ../home ];
    home.username = username;
    home.homeDirectory = homeDirectory;
    home.stateVersion = "<初回の値>";
  };
}
```

- `system.stateVersion` と `home.stateVersion` は**初回に導入したときの値で固定し、以後変えない**。家はホスト間でも
  そろえて、挙動を同一にしている。
- `dotfiles.onePassword.enable` は macOS では既定で `true` なので、家は書いていない
  ([`README.md` の「option」](../README.md#option))。

### `CLAUDE.md`

エージェントに core の `CLAUDE.md` を読ませるなら、利用側の `CLAUDE.md` は 1 行目に `@../dotfiles/CLAUDE.md` を置いて
core の `CLAUDE.md` を読み込み、その後に利用側に固有の事情 (構造、ホストの事情、エージェントの宣言の注意、適用のしかた)
だけを書く。core の原則と
[「踏むと痛い箇所」](../CLAUDE.md#踏むと痛い箇所)は写さない。読み込み先はクローンなので、lock を更新したら
core のクローンも pull する (6 節)。

### ホストを足すとき

家の判断の基準は**「壊さずに管理できるか」ではなく「管理する価値があるか」**。前者だけを見て Linux のホストを
対象に入れ、standalone の home-manager の構成を実装したうえで撤回したことがある (対象のホストが、対話的に使って
いないもの、別の仕組みで宣言的に管理されているものだった)。家で対象に入れないのは次のホスト。

- 対話的に使っていないホスト。**設定ファイルがそのホストに在ることを利用の証拠にしない** (かつて ssh の
  たびに `.zshrc` を転送する関数があり、転送の痕が残っていただけだった)。
- 既に別の仕組みで宣言的にプロビジョニングされているホスト。その仕組みが知らない状態を足すことになる。

家が使っている実測のコマンド:

```sh
$ last -20                                   # 人間が最後にログインしたのはいつか
$ stat -f %z ~/.zsh_history ~/.bash_history  # シェル履歴の量 (数十バイトなら使っていない)
$ ls -A ~                                    # 作業用のディレクトリがあるか
$ launchctl list | head -30                  # 何が常駐しているか
```

OS、ユーザーと uid、ホームディレクトリ、Nix と Homebrew の導入状況は**絶対パスで**確かめる
([`CLAUDE.md` の「踏むと痛い箇所」](../CLAUDE.md#踏むと痛い箇所)の「状態の判定を PATH 依存の経路で行わない」)。

CI は対象を宣言から取り出す (`builtins.attrNames`) ので、ホストを足しても CI を書き換えない。足したら既存の
ホストの `drvPath` が変わらないことを確かめる。

## 3. 値の置き方

環境固有の値は home-manager / nix-darwin の**標準の option に直接**書き、core の宣言とモジュールシステムに
マージさせる。core が読む値だけが `dotfiles.*` の option になっている
([`README.md` の「使い方」](../README.md#使い方)と[「option」](../README.md#option))。

```nix
# modules/home/default.nix
{ ... }:
{
  imports = [ ./packages.nix ];

  programs.git.settings.user = {
    name = "<owner>";
    email = "<owner>@users.noreply.github.com";
  };

  dotfiles.git.signingKeyName = "<項目名>";

  programs.ssh.settings = {
    # 所有者の Mac どうしだけが agent を転送する。
    "<host-a> <host-b>".ForwardAgent = true;
    # 中身が無くても消さない (zsh の補完の候補になる)。
    <host> = { };
    <host> = { HostName = "<名前解決できない相手だけ>"; User = "<user>"; };
  };
}
```

- **git の identity** は GitHub の noreply のアドレス。
- **署名鍵** は 1Password の項目名で指す。公開鍵の写しは置かない
  ([`README.md` の「コミット署名」](../README.md#コミット署名))。
- **authorized keys** は `keys/` の公開鍵ファイルを `openssh.authorizedKeys.keyFiles` で読む。家では署名と同じ鍵だが、
  署名の設定とは独立している。switch を `op` (1Password の CLI) に依存させないために、ファイルで持つ。
- **ssh の接続先** は `programs.ssh.settings`。
  - agent の転送は、所有者の端末どうしの 1 つのブロックにだけ置く。`Host *` に置かない。`-A` に頼らない
    (多重化接続では先に立った master が転送の有無を決める)。core の `ssh/rc` は転送先が所有者の端末だけで
    あることを前提にしている ([`README.md` の「利用側が与えるもの」](../README.md#利用側が与えるもの))。
  - 家では、名前解決できるホスト (家のネットワークの名前解決で引けるもの) には `HostName` を書かない。
  - 中身の無いブロックとブロックの並びの理由は [`CLAUDE.md` の「踏むと痛い箇所」](../CLAUDE.md#踏むと痛い箇所)
    (`programs.ssh.settings` のブロックの順序)。

### 鍵を入れ替える順序

署名と authorized keys が同じ鍵を指している家では、締め出し、GitHub での Unverified、push の失敗を避けるために
次の順序で入れ替える。1Password では SSH Key の項目の鍵を差し替えられないので、新しい項目を作って名前を移す。

1. 1Password に新しい鍵の項目を、**まだ別の名前で**作る (SSH agent が鍵を出す保管庫に置く)。
2. GitHub に新しい公開鍵を **signing key と authentication key の両方**として登録する。
3. `keys/` に新しい公開鍵を足し (`keyFiles` はリストなので旧い鍵と並べる)、すべての Mac で switch する。ssh 越しに
   switch するときは既存のセッションを閉じずに、別の接続で新しい鍵だけで入れることを確かめる。

   ```sh
   $ ssh -o IdentitiesOnly=yes -o ControlPath=none -i <新しい公開鍵のファイル> <host> true
   ```

   `IdentitiesOnly` が無いと agent が出す旧い鍵で通り、`ControlPath=none` が無いと直前の接続の master を使い回して
   認証をしないので、どちらが欠けても確かめたことにならない。
4. 1Password で**旧い項目の名前を先に変え**、それから新しい項目に `<項目名>` を付ける。同じ名前が 2 つあると署名は
   止まる ([`README.md` の「項目名の決め方と、変えるとき」](../README.md#項目名の決め方と変えるとき))。
5. 署名付きのコミットと push を行い、GitHub で Verified になることと push が通ることを確かめる。
6. `keys/` から旧い鍵を外して switch する (3 と同じく別の接続で確かめる)。旧い鍵で署名したコミットをすべて
   push してから、GitHub の旧い鍵を消し (push 済みのコミットは Verified のまま)、最後に 1Password の旧い項目を消す。

鍵が漏洩して入れ替えるときは、旧い鍵を待たずに GitHub と authorized keys から直ちに消す。sshd は公開鍵認証だけ
なので、鍵を壊すとリモートから締め出される ([`README.md` の「sshd は公開鍵認証だけ」](../README.md#sshd-は公開鍵認証だけ))。

## 4. 置き場所の判断

- **「どの環境でも使うか」で決め、迷ったら利用側に置く。** core のリストに置いたものは、利用側で引けない
  ([`README.md` の「リストに置いたものは、すべての利用側に入る」](../README.md#リストに置いたものはすべての利用側に入る))。
- **特定のエージェント製品の設定は利用側** ([`README.md` の「エージェントの設定は利用側が持つ」](../README.md#エージェントの設定は利用側が持つ))。
  一般的な道具 (`jq`、`ripgrep`、`fd`、`herdr`) は core にあり、家はそれに頼って重ねて宣言しない。頼るときは、
  頼っていることを宣言のコメントに書く (core が外したときに、評価では気づけないため)。
- **プロジェクトでだけ使うツールはグローバルに置かない。** そのプロジェクトの依存にする。家では、npm の
  パッケージだったツールを Homebrew から外し、それを使うプロジェクトの devDependency へ移した (Homebrew 版は
  依存を数十個引き込んでいた)。
- **使わなくなった宣言は残さない。** 家では、どの Mac でも使っていない言語のツールを撤去している。
- CLI ツールは Nix (`home.packages` / `programs.*`)、GUI アプリと App Store アプリは Homebrew (5 節)。

## 5. Homebrew の方針と理由

家の `modules/darwin/homebrew.nix`:

```nix
{ ... }:
{
  homebrew = {
    enable = true;
    taps = [ ];   # 非公式 tap を足すときは trusted = true を付ける
    onActivation = {
      autoUpdate = true;
      upgrade = false;
      cleanup = "uninstall";
    };
    casks = [ /* その環境でだけ使う GUI アプリ */ ];
    masApps = { /* "<mas list の名前>" = <id>; */ };
  };
}
```

非公式 tap の `trusted` の理由は [`CLAUDE.md` の「踏むと痛い箇所」](../CLAUDE.md#踏むと痛い箇所)。
`brews` は core の `mas` だけで、利用側は足していない。CLI は Nix で入れる。

**`autoUpdate = true`** — switch のたびに Homebrew 本体とメタデータを更新する。`false` にしていた時期に本体が
約 2 か月遅れ、cask 定義が使う新しい DSL を解釈できなくなり、switch が `brew bundle` で失敗した。cask 定義は
Homebrew の API から常に最新が配られるので、本体だけを止めると壊れる。

**`upgrade = false`** — switch は設定を変えるためのもので、全アプリを更新するためのものではない。Homebrew 側の更新は
CI で検証できない。上げるときは `brew upgrade` を意図して実行する。自動更新を持つ cask では、`brew outdated` の
表示はメタデータの遅れであることが多い。実際に古くなるのは自動更新を持たないもの (IDE、フォントなど)。

**`cleanup = "uninstall"`** — 宣言の外の formula と cask を消す。家ではこれで宣言と実物を一致させているが、危険も
持つ。

- 宣言から外したものは次の switch で消える。core のリストから外れたものも同じ。
- **`masApps` を 1 つでも宣言すると、宣言していない App Store アプリ (手で入れたものを含む) も消える。**
  nix-darwin のマニュアルは「`masApps` から外しても自動では消えない」と書いているが、この記述は古い
  (Homebrew 5.1.14 で `brew bundle` の cleanup が mas に広がった。nix-darwin の issue #1860)。
- App Store アプリの削除には、macOS の App 管理の許可 (システム設定 → プライバシーとセキュリティ → App 管理) を
  端末のアプリに与える必要がある。許可が無いと削除は失敗するが、**switch は成功で終わり、削除した件数の表示も
  信じられない** (`mas uninstall` の終了状態が捨てられる)。`mas list` で確かめる。削除されたアプリはゴミ箱に入る。

**削除対象の確かめ方** — 宣言を減らす変更と新しいホストの初回の switch の前に、適用するのと同じ宣言から Brewfile を
取って一覧を出す。

```sh
$ nix eval --raw '.#darwinConfigurations.<host>.config.homebrew.brewfile' > /tmp/Brewfile \
    && brew bundle cleanup --file=/tmp/Brewfile < /dev/null
```

- `&&` でつなぐ。`nix eval` が失敗してもリダイレクト先は作られ、空の Brewfile を渡すと導入済みのものが全部
  削除対象として並ぶ。
- **標準入力を切る。** `--force` が無い `brew bundle cleanup` は一覧の後に確認を求め、`y` を 1 文字打つと Enter を
  待たずに削除を始める。
- 削除対象があると `exit 1` で終わる。対象は formula と cask だけでなく、App Store アプリも出る。
- 新しいホストでは削除対象が想定よりずっと多いことがある (家では formula が 100 個を超えた)。

`brew bundle check` の読み方と ssh 越しの確かめ方は [`CLAUDE.md` の「踏むと痛い箇所」](../CLAUDE.md#踏むと痛い箇所)。

**既に `.app` があるホスト** — 手で入れた `.app` がある cask を宣言して switch すると、Homebrew は上書きせずに失敗し、
activation が Homebrew の段で止まる (system の世代だけが進んだ状態になる)。先に取り込む。

```sh
$ brew install --cask --adopt <cask>     # 既存の .app を管理下に取り込む (取り直さない)
```

**管理の外に置くもの** — 自動更新を持ち、Homebrew の管理下に置くと更新が止まるか意図しない版へ動くアプリ。家では
自動更新を持つエージェントの本体 (ベンダーのインストーラ) と、ベンダーのインストーラで入れた入力メソッド (cask の版が上で、
宣言するとメジャー版が上がる) を管理の外に置いている。どちらも新しい Mac では手で入れる。

## 6. 日々の運用

### core の変更を入れる

- core の変更は、利用側で **lock を更新したコミット** (`nix flake update core`) から switch して入れる。
  `--override-input core path:../dotfiles` は build と評価の確認だけに使い、付けたまま switch しない
  ([`README.md` の「変更を試す、反映する」](../README.md#変更を試す反映する))。
- **switch は所有者が、マージした利用側のコミットから行う。** 利用側で作業する人かエージェントは `darwin-rebuild build`
  までを行う。
- lock を更新したら core のクローンも pull する (`git -C ../dotfiles pull`)。lock とずれても構成には影響しないが、
  エージェントに core の `CLAUDE.md` を読ませているなら、その読み込み先が古くなる。

### lock の週次更新

家の `update-flake-lock.yml` は core の [`.github/workflows/update-flake-lock.yml`](../.github/workflows/update-flake-lock.yml)
とほぼ同じで、それを見本にしている。要点はそのコメントにある (固定のブランチを使い回す、変化が無ければ何もしない、
PR の本文は lock のコミットの本文、token の優先順位、`GITHUB_TOKEN` の push では CI が走らない)。

- 利用側の lock には **core も入る**ので、週次の更新で core の最新が入る。急ぐときは `nix flake update core` を
  PR にする。
- **core が宣言を外す変更は、利用側では lock の更新と宣言の追加を 1 コミットにする。** lock だけが先に上がると、
  その世代では宣言が消える (core の README の「エージェントの設定は利用側が持つ」の移行)。週次の自動の PR は
  core だけを上げる。利用側が、lock だけを上げた世代を評価で止める assertion を持つなら (家は持っている)、赤くなった PR は
  マージせずに閉じ、宣言を足したコミットで入れ直す。
- 家は private の Free プランで branch protection が使えない (API が 403) ので、**赤い PR のマージは止まらない**。
  赤い PR を入れないのは人の判断に依っている。
- lock の更新の PR で家が見るもの:
  - パッケージの出力から build 時に生成するもの (コマンド、skill) を持つ利用側は、その入力が上がったら
    `darwin-rebuild build` を通す。CI は評価だけで、生成は build で初めて走る。
  - 1 つの PR にまとめて上がった入力の破壊的な変更は、CI の評価で落ちる。

### CI

家の `ci.yml` は core の [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) と同じ形で、評価する構成だけが
違う (core は例の構成、家は全ホスト)。

- `nix flake check --no-build --all-systems` は `darwinConfigurations` を評価しないので、全ホストの `drvPath` を
  評価する段を別に置いている。対象は宣言から取り出す。
- ubuntu の runner で評価だけを行う (nix-darwin は IFD を使わないので評価できる)。macOS の runner は使わない。
- **activation のときにしか起きない失敗 (とくに `brew bundle`) は CI では捕まらない**
  ([`CLAUDE.md` の「踏むと痛い箇所」](../CLAUDE.md#踏むと痛い箇所))。

### drvPath の照合と OpenSpec

- 振る舞いを変えない意図の変更 (分割、モジュール化、core の同種の変更) は、**全ホストで** `drvPath` が一致する
  ことを確かめる ([`CLAUDE.md` の「振る舞い不変の検証」](../CLAUDE.md#振る舞い不変の検証-drvpath-照合))。
  家のホストは同一の `drvPath` になる。
- 規模のある変更は OpenSpec で proposal / design / specs / tasks を先に書き、フェーズごとにコミットして PR にする。
  破壊的な操作は対象の一覧を出して承認を得る ([`CLAUDE.md` の「作業の進め方」](../CLAUDE.md#作業の進め方))。
- コミットメッセージの本文に `##[` で始まる行を入れない
  ([`CLAUDE.md` の「コミットメッセージ」](../CLAUDE.md#コミットメッセージ))。lock の更新の workflow はコミットの本文を
  扱うので、利用側でも同じことが起きうる。

### 世代

- ロールバック: `sudo darwin-rebuild --rollback` で直前の世代へ戻る。`flake.lock` を git で戻して switch し直すと、
  入力の版ごと戻る。
- GC: system のプロファイルは sudo、ユーザーのプロファイルは sudo なしで消す。`--dry-run` で確かめてから行い、
  直前の数世代は残す (消した世代には `--rollback` で戻れない)。

  ```sh
  $ sudo darwin-rebuild --list-generations
  $ sudo nix-collect-garbage --delete-older-than 30d --dry-run
  $ sudo nix-collect-garbage --delete-older-than 30d
  $ nix-collect-garbage --delete-older-than 30d
  ```

### 新しい Mac

家の手順の流れ:

1. upstream の Nix を `--enable-flakes` だけで入れる (1 節)。
2. 利用側と core を ghq の配置でクローンする。別の Mac から agent を転送して入ってクローンすれば、`gh` の認証は
   要らない (この時点では 1Password の `IdentityAgent` がまだ置かれていないので、転送された agent が使われる)。
3. 5 節の `--adopt` と削除対象の確認をしてから、初回の build と switch をする。初回は `darwin-rebuild` がまだ無い
   ([`README.md` の「`darwin-rebuild` について」](../README.md#darwin-rebuild-について))。
4. switch がインストーラの書いた `/etc` のファイルで止まったら、案内されたファイルに `.before-nix-darwin` を付けて
   退避し、switch をやり直す。**退避は `nix build` の後に行う** — `/etc/zshrc` は nix を `PATH` に入れ、
   `nix.conf` は flakes を有効にしているので、先に退避すると `nix build` が動かない。
5. `result` を消す (GC ルートを残さない)。
6. 退避された `.hm-bak` は差分を取ってから消す ([`CLAUDE.md` の「踏むと痛い箇所」](../CLAUDE.md#踏むと痛い箇所))。
   家では、あるホストでだけ有効にしていた設定が `.hm-bak` に残っていた。

## 7. 秘密の扱い

- **秘密 (SSH の秘密鍵、API トークン、kubeconfig の client-secret) は private のリポジトリにも置かない。** 秘密鍵は
  1Password の SSH agent が持ち、リポジトリには公開鍵だけを置く。
- **Nix の store は誰でも読める。** 宣言に書いた値は store に入る。
- 家は MCP のキーを 1 つ、**秘密として扱わない**と判断して家のリポジトリと store に置いている (漏れて起きるのは
  無料枠の消費だけ)。値は別のファイルに分けて宣言から読み (ファイルの中身は宣言に写さない)、エージェントが宣言を読むたびに値が
  文脈に入らないようにしている。家のエージェントはそのファイルを開かず、`git show` や `nix derivation show` で値を
  出力しない。
- 秘密として扱う資格情報を MCP に足すときに家が検討した案は、1Password から読むもの。その問題は、解錠している間は
  エージェントも読めること、ssh 越しでは承認が接続先の無人の画面に出ること。

## 8. core を直したいとき

- core のクローンで編集し、利用側から `--override-input core path:../dotfiles` で評価と build を確かめ
  ([`README.md` の「変更を試す、反映する」](../README.md#変更を試す反映する))、core に PR を出す。マージした後、
  利用側で lock を更新する。振る舞いを変えない意図の変更は、利用側の全ホストで `drvPath` を照合する。
- **core は public。** 公開の決まりは [`CLAUDE.md` の「public のリポジトリとしての決まり」](../CLAUDE.md#public-のリポジトリとしての決まり)。
  所有者の家の端末には公開の前の検査があるが、その語の一覧は公開していないので、**ほかの端末には同じ検査が無い**。
  core に向けたコード、コメント、コミットメッセージ、ブランチ名、PR と issue の文章に、利用側の固有名 (ホスト名、
  ドメイン、アドレス、ネットワークの構成、社名、社内のツールやリポジトリの名前) が無いことは、書いた側が自分で
  確かめることになる。実測は役割の名前 (接続元の Mac、接続先の Mac、所有者の端末) で書く。

## 9. 知見を返す (申し送り)

- 利用側から core と家の構成へは直接送れない。返したい知見 (core に足すべき一般的な注意、この手引きの誤り、
  core の不具合) は、**利用側のリポジトリの中に申し送りとして書き残し、人間が持ち出す。** core や家の構成へ
  直接書き込まない。
- 申し送りは core に入りうるので、**利用側の固有名を含まない形** (役割の名前) で書く。利用側に固有の記録とは
  分けて置く。
- 置く場所は利用側が決める。人間が見つけられるよう、利用側の `README.md` から案内しておく。

## 10. 家にあって、この手引きに書かないもの

家の構成には次の種類のものもあるが、この手引きには載せていない (名前と値は家に固有なので)。手引きに無いことは
「家に無い」ことを意味しない。

- 家でだけ使う CLI ツール、cask、App Store アプリ
- 家のサーバーへの ssh の接続先
- 家のクラスタへの接続の宣言 (kubeconfig の接続先と OIDC の認証方式を宣言から生成し、kubectl が書き込む値は
  書き込める別のファイルに置く形)
- core への公開の前の検査 (私的な語の一覧、core のクローンの pre-push フック、エージェントの `gh` の書き込みの
  検査、core の毎日の走査)
- 対象外にしたホストとその理由の記録
- 家の個別の鍵の項目名と、agent を転送するホストの組
