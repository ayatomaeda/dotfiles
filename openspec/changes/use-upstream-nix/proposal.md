## Why

所有者は、Nix の本体に NixOS が配布する upstream の Nix を使うと決めた。現在は Determinate Nix を前提にしており、
core が `nix.enable = false` で nix-darwin の Nix の管理を止めているので、core を使う利用側はすべて Determinate Nix を
入れることになる。CI も Determinate Systems の action で Nix を入れている。

## What Changes

- **BREAKING:** core は Determinate Nix を前提にしない。`nix.enable = false` を外し、Nix の設定 (`/etc/nix/nix.conf`)
  と daemon を nix-darwin に管理させる。Determinate Nix が入った Mac でこの構成に switch すると、nix-darwin の検査
  (`Determinate detected, aborting activation`) で止まる。利用側は、core を上げた lock のコミットから、各 Mac の Nix を
  入れ替えながら switch する。
- core が `nix-command` と `flakes` を有効にする。upstream の Nix はどちらも既定で無効であり、どの利用側も flake で
  構成を適用するため。
- channel を無効にする。構成は flake だけで扱い、`nixpkgs` の参照は nix-darwin が lock の rev に固定した registry で
  解決する。
- CI で Nix を入れる action を、NixOS の公式リリースを入れるものに替える。`flake.lock` の定期更新を
  `DeterminateSystems/update-flake-lock` から、`nix flake update` と `gh` による PR の作成に替える。PR のタイトル、
  ラベル、使い回すブランチ、token の優先順位は今と同じにする。
- `nix flake check` が `darwinConfigurations` を評価するという、Determinate Nix でだけ成り立つ記述を CI から除く。
  全ホストの評価は、すでにある後段のステップが受け持つ。
- 各 Mac で Determinate Nix から upstream の Nix へ入れ替える手順を README に書く。
- README と CLAUDE.md から Determinate Nix の前提と、それに由来する注意 (`nix search nixpkgs` が lock を見ない) を除く。

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `system-bootstrap`: 「Determinate Nix と nix-darwin の管理境界」を、upstream の Nix を nix-darwin が管理する要件に
  置き換える。flakes の有効化、channel の無効化、registry の固定、Determinate Nix からの入れ替えの手順を含める。
- `config-validation`: 既存の 2 要件を改める。「構成の破壊は適用前に検出する」に、CI が upstream の Nix で評価すること
  と、全ホストの評価を `nix flake check` の実装に依存させないことを足す。「入力の更新は自動的な提案として受け取る」に、
  Determinate Systems の action を使わないこと、更新した PR でも CI が走ること、更新が無い週に PR を変えないことを足す。
- `package-management`: パッケージの有無の確認のしかたから、Determinate Nix の `extra-nix-path` に由来する理由を除く。

## Impact

- **コード:** `modules/darwin/default.nix`。
- **CI:** `.github/workflows/ci.yml`、`.github/workflows/update-flake-lock.yml`。
- **文書:** `README.md`、`CLAUDE.md`。
- **利用側:** core を上げた lock で switch できるのは、Nix を入れ替えた Mac だけになる。入れ替えでは `/nix` が消え、
  それより前の世代には戻れない。作業中は sshd の公開鍵認証、Touch ID の sudo、home-manager の設定が一時的に使えない。
  利用側のリポジトリの workflow と導入手順も、同じ方針で直す (この change の外)。
- **生成物:** `drvPath` は変わる (意図した変更)。nix-darwin の側で `/etc/nix/nix.conf`、`/etc/nix/registry.json`、
  launchd の `nix-daemon`、`environment.systemPackages` の `nix` が増える。home-manager は OS の `nix.package` を受け取るので
  `home.activationPackage` は変わるが、`home-files` と `home.path` は変わらないことを確かめる。
