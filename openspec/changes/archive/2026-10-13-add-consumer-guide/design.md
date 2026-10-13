## Context

動機は proposal.md の「Why」。ここでは手引きの形を決めるための現状だけを書く。

- core の文書は、core が**提供するもの**を説明している。`README.md` (使い方、option、利用側が与えるもの、リストの
  性質、エージェントの設定は利用側が持つこと、変更を試す手順、コミット署名、端末のツール)、`CLAUDE.md` (公開の決まり、
  構造の原則、drvPath の照合、コミットメッセージ、踏むと痛い箇所)、`docs/GUIDE.md` (キーとコマンド)。
  評価用の例の構成 (`darwinConfigurations.example`) が利用側の書き方の最小の見本を兼ねる。
- 利用側の**作り方と運用**は、家の構成 (private) の README、CLAUDE.md、モジュール、workflow、spec にしか無い。
  会社の PC で利用側を作るエージェントは、core のクローンしか読めない。
- core の `.github/workflows/` には、家とほぼ同じ CI (評価) と lock の週次更新の workflow がある。
- core は public。所有者の家の端末には公開の前の検査 (私的な語の一覧による検査、pre-push、`gh` の書き込みの検査) が
  あるが、会社の端末には無い。語の一覧は公開しないので、会社の端末からは同じ検査を実行できない。
- 手引きの鮮度は、家の側の仕組み (家の変更と core を上げる lock の更新のたびに手引きへの影響を見るもの) が保つ。
  その仕組みは家の側の change で作り、core はそれを参照しない。

## Goals / Non-Goals

**Goals:**

- core だけが見える端末のエージェントが、手引きと core の文書だけで利用側のリポジトリを作り、運用できる。
- 家の形を採った理由と前提が読み手に渡り、読み手が自分の環境で同じ検討をやり直さずに判断できる。
- 手引きを足しても、core の文書の中で古くなりうる箇所 (同じ説明の写し) が増えない。

**Non-Goals:**

- 会社の構成の設計。読み手の環境への合わせ方は読み手が決める (spec「手引きは家の形と理由を書き、読み手の判断を指示しない」)。
- 利用側のひな形 (flake template、`nix flake init -t`)。D1 の代案を参照。
- 手引きの鮮度を保つ仕組み。家の側の change が持つ。
- core のモジュール、option、生成物の変更。

## Decisions

### D1. 手引きは core の `docs/CONSUMER-GUIDE.md` の 1 ファイルにする

core の文書のうち、利用側を**作る人**に向けたものを 1 か所に置く。core の README は core を**使う**人の参照で、
運用の手順 (lock の更新、switch、Homebrew の方針) を足すと、core の説明と利用側の家の運用が混ざる。

代案:

- 家の構成に置く → 会社の端末から見えない。
- core の README に節を足す → README は今でも長く、家の運用 (core の性質ではないもの) が core の説明に見える。
- ひな形 (flake template) を core に置く → 採らない。ひな形は値の選び方を暗黙に指示し (D2 に反する)、
  家の形が変わるたびに古くなるコードが増える。最小の書き方の見本は評価用の例の構成がすでに担っている。
- 別の public リポジトリ → 管理する場所が増え、core の文書へのリンクが別のリポジトリをまたぐ。

### D2. 「家ではこうしている」と「その理由と前提」を書き、指示しない

各節は、家の値やコード、それを採った理由 (退けた案、実測で踏んだ失敗)、それが成り立つ前提の順に書く。
「会社ではこうせよ」「所有者に確かめよ」は書かない。所有者に確かめる事項の一覧も持たない。前提が会社で
成り立つかは読み手が判断し、必要なら読み手が所有者に尋ねる。

理由: 会社の事情 (使ってよいアプリ、ネットワーク、認証、MDM) は手引きを書く側から見えない。指示を書くと、
見えない事情と衝突したときに読み手が指示と事実のどちらに従うかで迷う。理由と前提を渡せば、読み手は事実と
照らして判断できる。

### D3. 固有名は抜き、家に固有の部分は種類だけを書く

- **書かない:** 家のホスト名、ドメイン、アドレス、ネットワークとクラスタの構成、認証基盤の値 (issuer、client id、
  audience)、ユーザー名、家でだけ使うアプリとツールの名前、家のリポジトリのコミットのハッシュ、家のほかの
  リポジトリの名前。
- **プレースホルダにする:** `<user>`、`<host>`、`<項目名>`、`<owner>`。所有者の GitHub のアカウント名と core の
  リポジトリ名は、core の README がすでに書いているので、そのまま使う。
- **値を載せない:** 秘密と、秘密として扱わない資格情報 (MCP の API キー)。手引きには「利用側のファイルから読む形」
  だけを載せる。そのファイルは手引きを書く作業でも開かない。
- **種類だけを書く:** D6 の「家にあって書かないもの」。

実装の後、所有者の端末で家の構成の検査スクリプトに core を渡して確かめる (tasks)。検査が当たったら、
語の一覧を変えずに手引きの文章を書き直す。

### D4. core の文書と重なる説明はリンクにする

手引きは利用側に固有の形と運用だけを書き、core にある説明は見出しへのリンクで参照する。リンク先は相対パス
(`../README.md#…`) で書き、会社の端末のクローンでもたどれるようにする。手引きから参照する core の箇所:

| 手引きの話題 | 参照する core の箇所 |
|---|---|
| `flake.nix` の最小の形、option、利用側が与えるもの | `README.md` の「使い方」「option」「利用側が与えるもの」 |
| 置き場所の性質 (リストは利用側で引けない) | `README.md` の「リストに置いたものは、すべての利用側に入る」 |
| Claude Code の設定を利用側が持つこと、移行 | `README.md` の「エージェントの設定は利用側が持つ」 |
| `--override-input` での確かめ方 | `README.md` の「変更を試す、反映する」 |
| 署名鍵の項目名 | `README.md` の「コミット署名」 |
| 公開の決まり、コミットメッセージの `##[` | `CLAUDE.md` の「public のリポジトリとしての決まり」「コミットメッセージ」 |
| drvPath の照合 | `CLAUDE.md` の「振る舞い不変の検証」 |
| `cleanup = "uninstall"`、`brew bundle check`、非公式 tap、`darwin-rebuild` と初回、sshd、`.hm-bak`、`//`、PATH 依存の判定、シェルスナップショット | `CLAUDE.md` の「踏むと痛い箇所」 |
| CI と lock の週次更新の workflow | `.github/workflows/` (core の workflow を見本として参照する) |
| 要件 | `openspec/specs/` |

core の側の記述が変わってもリンク先の見出しが残る限り手引きは古くならない。見出しが変わったときにリンクが
切れることは、実装のときに見出しの一覧と突き合わせて確かめる (tasks)。

### D5. 手引きの骨組みと、載せる内容

冒頭の 3 行の後に、次の節を置く。各節の「載せる内容」は家の構成から読み取ったもので、実装はここから書く。

**冒頭** — 表題、`最終照合: YYYY-MM-DD` の行 (D7)、この文書の読み方 (家の形と理由を書く。合わせ方は読み手が決める。
core の説明はリンク先にある)。

**1. 読み手と前提**

- 読み手: core だけが見える端末で、利用側のリポジトリを作って運用するエージェント。家の構成 (private) は読めない。
- 家の前提: macOS (Apple Silicon)、upstream の Nix (公式のインストーラで `--enable-flakes` だけを付けて入れる。ほかの
  フラグを付けると nix-darwin が `nix.conf` を既知のものと認めず switch が止まる)、nix-darwin + home-manager、
  1Password の SSH agent、Homebrew が `/opt/homebrew` にある。
- 役割: 編集と非破壊の確認 (評価、build、dry-run) はエージェント、switch は所有者。
- クローンの配置: ghq の配置 (`~/git/github.com/<owner>/<repo>`) で、core のクローンを利用側のクローンの隣に置く。
  隣にあることが、`CLAUDE.md` の読み込み (`@../dotfiles/CLAUDE.md`) と `--override-input core path:../dotfiles` の前提。
  core のクローンは構成の build には要らない (input は lock した GitHub の版を読む)。

**2. リポジトリの形**

- ディレクトリの図: `flake.nix`、`hosts/<host>/default.nix`、`modules/darwin/` (`default.nix`、`homebrew.nix`、
  Claude Code の宣言を確かめる assertion)、`modules/home/` (`default.nix`、`packages.nix`、Claude Code まわり)、
  `claude/` (ステータスラインのスクリプト)、`keys/` (公開鍵)、`openspec/`、`.github/workflows/`、`CLAUDE.md`、`README.md`、
  `docs/GUIDE.md`。
- `flake.nix` の inputs: `nixpkgs` は `nixpkgs-unstable` (lock で再現性を持つので unstable。darwin のパッケージの網羅と
  鮮度)、`nix-darwin` と `home-manager` は master で `nixpkgs` を follows、`core` は 3 つを follows (そろえないと
  nixpkgs を 2 つ取り、core のモジュールが別の版で評価されうる)、Claude Code のスキルの上流を `flake = false` で lock。
  `specialArgs` で `core` とスキルの上流を渡し、`home-manager.extraSpecialArgs` で home のモジュールへ渡す。
- core の README の例との違い: 家は `hosts/<host>` から `modules/darwin` を import し、`flake.nix` の modules には
  `hosts/<host>`、home-manager の darwin モジュール、`core.darwinModules.default` だけを並べる。
- `hosts/<host>/` は `nixpkgs.hostPlatform` だけ。家のホストは宣言が同一で、差が出た時点でホスト側に書く。ホストごとの
  層化 (cask の出し分けなど) はしていない。
- ユーザー名とホームディレクトリは `let` で 1 か所に定義する (`users.users.<user>.home` と `home.homeDirectory` が
  ずれると home-manager が別の場所へ配備する)。
- `stateVersion` は初回の値で固定し、ホスト間でそろえる (家の値は書かない。読み手が初回の値を選ぶ)。
- `CLAUDE.md` は 1 行目で core の `CLAUDE.md` を読み込み、その後に利用側に固有の事情だけを書く。
- ホストを足すとき: 「壊さずに管理できるか」ではなく「管理する価値があるか」で決める (対話的に使っていないホスト、
  既に別の仕組みで宣言的に管理されているホストは入れない。設定ファイルが在ることを利用の証拠にしない)。実測の
  コマンド (`last`、シェル履歴の大きさ、常駐するもの) と、前提の実測は絶対パスで行うこと。家は Linux を一度対象に
  入れて撤回した (種類だけを書く)。CI は対象を宣言から取り出すので、ホストを足しても CI を書き換えない。

**3. 値の置き方**

- 環境固有の値は標準の option に直接書く。core が読む値だけが `dotfiles.*` (リンク)。
- git の identity は GitHub の noreply のアドレス。署名は 1Password の項目名で指す (`dotfiles.git.signingKeyName`。
  リンク)。
- authorized keys は `keys/` の公開鍵ファイルを `openssh.authorizedKeys.keyFiles` で読む。署名とは独立。
  switch を `op` に依存させないためにファイルで持つ。
- ssh の接続先は `programs.ssh.settings`。agent の転送は所有者の端末どうしの 1 つのブロックにだけ置く
  (`Host *` に置かない、`-A` に頼らない)。名前解決できるホストには `HostName` を書かない。中身の無いブロックは
  補完の候補のために残す (理由はリンク)。
- 鍵を入れ替える順序 (新しい項目を別の名前で作る → GitHub に signing と authentication の両方で登録 → `keys/` に
  並べて switch し、`IdentitiesOnly` と `ControlPath=none` を付けて新しい鍵だけで入れることを確かめる → 旧い項目の
  名前を先に変えて新しい項目に名前を移す → Verified と push を確かめる → 旧い鍵を外す)。漏洩のときは待たずに消す。

**4. 置き場所の判断**

- 「どの環境でも使うか」で決め、迷ったら利用側に置く。core のリストは利用側で引けない (リンク)。
- 特定のエージェント製品の設定は利用側 (リンク)。一般的な道具 (`jq`、`ripgrep`、`fd`、`herdr`) は core にあり、
  利用側はそれに頼ってよく、重ねて宣言しない。頼るときは宣言のコメントに書く。
- プロジェクトでだけ使うツールはグローバルに置かず、そのプロジェクトの依存にする (家の実例: npm のツールを
  プロジェクトの devDependency へ移した。名前は書かない)。
- 使わなくなった宣言は残さない。

**5. Homebrew の方針と理由**

- 家の値: `enable = true`、`taps = [ ]` (非公式 tap は `trusted = true` を付ける。リンク)、`onActivation` は
  `autoUpdate = true`、`upgrade = false`、`cleanup = "uninstall"`。
- `autoUpdate = true` の理由: false にした時期に Homebrew 本体が約 2 か月遅れ、cask 定義の新しい DSL を解釈できず
  switch が `brew bundle` で失敗した。
- `upgrade = false` の理由: switch は設定を変えるためのもので、全アプリの更新ではない。Homebrew の更新は CI で
  検証できない。上げるときは `brew upgrade` を意図して実行する。自動更新を持つ cask では `brew outdated` の表示は
  メタデータの遅れであることが多い。
- `cleanup = "uninstall"` の危険: 宣言から外したものは次の switch で消える。`masApps` を 1 つでも宣言すると、宣言して
  いない App Store アプリ (手で入れたものを含む) も消える (nix-darwin のマニュアルの記述は古い)。削除には App 管理の
  許可が要り、許可が無いと失敗するが switch は成功で終わり、件数の表示も信じられない (`mas list` で確かめる)。
- 削除対象の確かめ方: 適用する宣言から Brewfile を `nix eval` で取り、`&&` でつないで `brew bundle cleanup --file=…
  < /dev/null` (標準入力を切らないと `y` 1 文字で削除が始まる。`nix eval` が失敗しても出力先は作られる)。対象が
  あると `exit 1` で終わる。
- 新しいホストで既に `.app` がある cask は、`brew install --cask --adopt` で取り込んでから switch する (取り込まないと
  activation が Homebrew の段で止まる)。
- 管理の外に置くもの: 自動更新を持ち、Homebrew の管理下に置くと更新が止まるか意図しない版へ動くアプリ
  (Claude Code 本体、ベンダーのインストーラで入れた入力メソッド)。
- `brews` は core の `mas` だけ。CLI は Nix で入れる。

**6. Claude Code を宣言する場合の家の形**

コード片を固有名抜きで載せる。core の README の「エージェントの設定は利用側が持つ」を前提にする。

- `modules/home/claude-code.nix`: `package = null` (本体は自動更新される native インストーラ)、`settings`
  (`statusLine` は store の絶対パス、`enabledPlugins`、`syncClaudeAiSkills = false`、`deniedMcpServers` で組み込みの
  ブラウザ連携を止める、`permissions.allow` の MCP の規則は home-manager の個人プラグインの名前 `hm` に依存する)、
  `skills` はスキルごとに上流の input から選ぶ、`mcpServers` (playwright、context7。キーは別ファイルから
  `builtins.readFile` で読む形だけを載せる)。
- `programs.claude-code.marketplaces` を使わず `settings.extraKnownMarketplaces` に書く (Claude Code が書き換える
  ファイルを読み取り専用にするため)。`claude mcp add` で登録しない (同じ endpoint の宣言のほうが黙ってつながらない)。
- ステータスライン: `claude/statusline-command.sh` を `writeShellScript` で store に入れる (shebang を外して渡し、
  1 行目を assertion で確かめる)。bash が必要。core の `jq` と `git` に頼る。リセット時刻の表示は BSD の `date -r`。
  スクリプトの本体は全文を折りたたみで載せる (家の私的な情報を含まない。会社の端末からほかに手に入らない)。
- `modules/home/openspec.nix`: OpenSpec の CLI と、同じ版から build 時に生成する `/opsx:*` のコマンド。build の中で
  `HOME` を一時ディレクトリに向け、生成されるはずのコマンドが無ければ build を止める。各リポジトリに写しを置かない
  (`openspec init --tools none`)。
- `modules/home/herdr-skill.nix`: core が有効にした herdr のパッケージの `herdr --skill` から skill を生成する
  (`npx skills` や上流の master から取らない。版がずれる)。build のときにしか壊れが分からない。
- `modules/darwin/claude-code-guard.nix`: `programs.claude-code.enable` と cask `claude` が有ることの assertion。
  core が宣言を外した lock を、評価で止める。
- hook を別のモジュールから `programs.claude-code.settings.hooks` に足すとマージされる。`enable` を外すと hook も
  黙って消える。
- 保存されない操作 (`/config`、`/theme`、権限の「常に許可」、プラグインの切り替え、`claude mcp add`) と恒久的に
  変える場所の表。`settings.json` の変更は switch の後に起動したセッションにだけ効く (古いセッションは古い設定で
  `~` を書き換え続ける)。
- 宣言に寄せたときの各 Mac の後片付け (`claude mcp list` / `remove`、宣言から外したプラグインのアンインストール、
  同期されたスキルが無いことの確認)。

**7. 日々の運用**

- lock の週次更新: core の `update-flake-lock.yml` を見本にする (固定のブランチ、変化が無ければ何もしない、PR の
  本文は lock のコミットの本文、token の優先順位、`GITHUB_TOKEN` の push では CI が走らない)。利用側の lock には
  core も入る。
- core だけを上げる更新の扱い: core が宣言を外す変更は、利用側では lock の更新と宣言の追加を 1 コミットにする。
  自動の PR が assertion で赤くなったらマージせず閉じる。家は private の Free プランで branch protection が使えない
  ので、赤い PR のマージは止まらない (前提として書く)。
- lock の更新の PR で見るもの: スキルの上流の差分 (エージェントへの指示とスクリプトが変わる)、herdr が上がったら
  `darwin-rebuild build` (skill の生成は評価では止まらない)。lock を更新したら core のクローンも pull する
  (`CLAUDE.md` の読み込み先)。
- `--override-input` は build と評価だけ (リンク)。switch は所有者が、マージした利用側のコミットから行う。
- CI: `nix flake check --no-build --all-systems` は `darwinConfigurations` を評価しないので、全ホストの drvPath を
  評価する段を別に置く (core の `ci.yml` を見本にする)。activation の失敗 (`brew bundle`) は CI では捕まらない。
- drvPath の照合は全ホストで行う (リンク)。
- OpenSpec: 規模のある変更は proposal / design / specs / tasks を先に書き、フェーズごとにコミットして PR にする。
- 世代の扱い: ロールバック (`darwin-rebuild --rollback`、lock を戻して switch)、GC (`--dry-run` で確かめてから、
  system は sudo、ユーザーは sudo なし。直前の数世代は残す)。
- 新しい Mac: Nix の導入、クローン、初回の build と switch (リンク)、`/etc` のファイルで止まったら `.before-nix-darwin`
  を付けて退避する (退避は `nix build` の後)、Claude Code の native インストーラ。

**8. 秘密の扱い**

- 秘密 (SSH 秘密鍵、API トークン、kubeconfig の client-secret) は private のリポジトリにも置かない。秘密鍵は
  1Password の SSH agent が持ち、リポジトリには公開鍵だけを置く。
- store は誰でも読める。宣言に書いた値は store に入る。
- 家は MCP のキー 1 つを秘密として扱わない判断をしている (漏れて起きるのは無料枠の消費だけ)。値は別ファイルに
  分け、エージェントが宣言を読むたびに値が文脈に入らないようにしている。秘密として扱う資格情報を足すときに家が
  検討した案 (1Password から読む) と、その問題 (解錠中はエージェントも読める、ssh 越しでは承認が無人の Mac に出る)。

**9. core を直したいとき**

- core のクローンで編集し、利用側から `--override-input` で評価と build を確かめ、core に PR を出す。マージした後、
  利用側で lock を更新する。
- 公開の決まり (リンク)。会社の端末には公開の前の検査が無く、語の一覧も見えないので、コード、コメント、コミット
  メッセージ、ブランチ名、PR の文章に会社の固有名が無いことを自分で確かめる。

**10. 知見を返す (申し送り)**

- 利用側から core と家へは直接送れない。返したい知見は、利用側のリポジトリの中に申し送りとして書き、人間が持ち出す。
- 申し送りは core に入りうるので、会社の固有名を含まない形 (役割の名前) で書く。会社に固有の記録とは分けて置く。
- 置く場所は読み手が決める。人間が見つけられるよう、利用側の README から案内する。

**11. 家にあって書かないもの (種類だけ)**

- 家でだけ使う CLI ツール、cask、App Store アプリ
- 家のサーバーへの ssh の接続先
- 家のクラスタへの接続の宣言 (kubeconfig の接続先と OIDC の認証方式を宣言から生成し、kubectl が書き込む値は
  書き込める別のファイルに置く形。値は書かない)
- core への公開の前の検査 (私的な語の一覧、pre-push フック、`gh` の書き込みの検査、毎日の走査)
- 対象外にしたホストとその理由の記録
- 家の個別の鍵の項目名とホストどうしの転送の組

### D6. 「家にあって書かないもの」の節を置く

種類だけを書く節を置き、読み手が「家には何があって手引きには無いのか」を知れるようにする。無いと、読み手は
手引きに無いものを「家に無い」と読み違える。値や名前は書かない (D3)。

### D7. `最終照合:` の行

表題の直後に `最終照合: YYYY-MM-DD` を 1 行で置く。日付は手引きを家の構成と突き合わせた日で、編集した日ではない。
この書式は家の照合の仕組みが読むので、ほかの語や括弧を足さない。家のコミットのハッシュは書かない (家は private で、
ハッシュは読み手に意味が無く、家の履歴の情報を出す)。

手引きの鮮度は家の側の仕組みが保ち、core は家を参照する仕組みを持たない (spec「手引きは最終照合の日付を持つ」)。
core の文書には、手引きが家の構成を情報源にしていることと日付の意味だけを書き、家の仕組みの詳細は書かない。

### D8. README と CLAUDE.md からの案内

- `README.md`: 冒頭の段落 (利用側が取り込む) の後に 1 文で案内し、「ファイル / ディレクトリ」の表に
  `docs/CONSUMER-GUIDE.md` の行を足す。
- `CLAUDE.md`: 冒頭の段落の「使い方は `README.md`、日々の操作は `docs/GUIDE.md`」に、「利用側のリポジトリの作り方と
  運用は `docs/CONSUMER-GUIDE.md`」を足す。

## Risks / Trade-offs

- [手引きが家の構成とずれる] → 家の側の照合の仕組みが、家の変更と lock の更新のたびに影響を見る。読み手は
  `最終照合:` の日付で古さを判断できる。
- [家の私的な情報が手引きに入る] → 所有者の端末で語の一覧による検査を通す (tasks)。一覧に無い語 (家の
  アプリの名前など) は検査では止まらないので、D3 の「書かない」を書くときに守る。
- [core の文書の見出しが変わってリンクが切れる] → 実装のときにリンク先の見出しを突き合わせる。以後の core の
  変更で見出しを変えるときは、手引きのリンクも直す (`rg 'CONSUMER-GUIDE\|#' docs/CONSUMER-GUIDE.md`)。
- [コード片が家の現在の宣言とずれる] → 載せるのは形を示すための片で、家の実体の写しを保つことは約束しない。
  照合の仕組みが大きなずれを拾う。
- [指示しない書き方では読み手が迷う] → 理由と前提を必ず添える。判断に要る事実が読み手の環境にあることは避けられない。
- [会社の端末からの core の変更が私的な情報を含む] → 手引きが、検査が無いことと自分で確かめることを書く。
  公開後に見つかるものは家の走査が拾う (core からは仕組みの詳細を書かない)。

## Migration Plan

1. 手引きを書く。
2. README と CLAUDE.md から案内する。
3. 所有者の端末で検査と `openspec validate` を通し、PR にしてマージする。
4. archive して `openspec/specs/consumer-guide/` に反映する。

モジュールと生成物は変わらないので、利用側の lock の更新は急がない (core の文書はクローンの pull で読める)。
戻すときは、手引きのファイルと案内の行を消すコミットを作る。
