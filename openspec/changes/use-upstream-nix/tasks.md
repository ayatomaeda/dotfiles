## 1. 基準の記録

- [ ] 1.1 このリポジトリの main を指して、利用側で `--override-input core path:../dotfiles` を付け、各ホストの toplevel の drvPath、`environment.etc` の名前の一覧、`launchd.daemons` の名前の一覧、`environment.systemPackages` の名前の一覧、home-manager の `home-files` と `home.path` の drvPath を記録する

## 2. core

- [ ] 2.1 `modules/darwin/default.nix` から `nix.enable = false` とそのコメントを消し、`nix.settings.experimental-features = [ "nix-command" "flakes" ]` と `nix.channel.enable = false` を置く。コメントに、Nix の設定と daemon を nix-darwin が管理すること、flakes を core に置く理由 (nix-darwin が `nix.conf` を置き換える)、channel を無効にする理由 (flake だけで扱い、`nixpkgs` は lock に固定した registry で解決する)、利用側が与える前提 (その Mac の Nix は Determinate ではないこと。Determinate が残っていると activation が止まる) を書く
- [ ] 2.2 このリポジトリで `nix flake check --no-build --all-systems` と example の toplevel の評価が通ることを確かめる

## 3. CI

- [ ] 3.1 `ci.yml` の `DeterminateSystems/determinate-nix-action@v3` を `cachix/install-nix-action` (現行の major) に替える
- [ ] 3.2 `ci.yml` のコメントを直す (design D8): upstream の `nix flake check` は `darwinConfigurations` を評価しないこと、後段の全ホストの評価が構成を評価する唯一のステップであること、`nix flake show --json` の形 (`{"type":"unknown"}`) の記述
- [ ] 3.3 `update-flake-lock.yml` を design D7 の形に書き換える: token を選ぶステップを checkout の前に移して checkout に渡す、`cachix/install-nix-action`、author を `github-actions[bot]` にした `nix flake update --commit-lock-file`、リモートの `update_flake_lock_action` (無ければ main) の `flake.lock` と同じなら終了、force push、PR が無ければ `gh pr create` (タイトル・ラベル・本文はコミットの本文)、あれば `gh pr edit --body`。token の優先順位と説明は維持し、ラベルを消すと失敗することをコメントに書き、`id-token: write` を削除する
- [ ] 3.4 2 つの workflow に `nix run --inputs-from . nixpkgs#actionlint` をかけ、`client-id` の既知の誤検知以外の指摘が無いことを確かめる

## 4. 文書

- [ ] 4.1 README の「`darwin-rebuild` について」の近くに「Determinate Nix から upstream の Nix への入れ替え」を足す (design D4、D5)。手順の前に次を書く: `/nix` が消えて前の世代に戻れないこと。作業中は sshd がパスワード認証を受け付けて公開鍵認証が効かないこと (信頼できるネットワークで行う)。Touch ID の sudo と home-manager の設定 (シェル、ssh、git) が使えないこと。Terminal.app の素のシェルで tmux と herdr の外で行うこと。接続先の Mac は、その Mac の前で行うか、herdr を通さない ssh で、既存の接続を閉じずに uninstaller の後で別の接続からパスワードでログインできることを確かめてから進むこと。コミットは switch の後に行うこと。利用側の週次の lock 更新の PR を入れ替えの前にマージしないこと
- [ ] 4.2 4.1 の手順本体を書く: 利用側で core を上げた PR をマージしたコミットを pull → `sudo darwin-uninstaller` → `sudo /nix/nix-installer uninstall` (nix-darwin が残っていると拒否されるので、そのときは新しいターミナルで `which darwin-rebuild` が空か確かめる) → 新しいターミナルで `curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes` (ほかのフラグを付けない) → 新しいターミナルで `nix build .#darwinConfigurations.<host>.system` → `sudo ./result/sw/bin/darwin-rebuild switch --flake .#<host>` (`/etc` の既存ファイルで止まったら `.before-nix-darwin` に退避して再実行。`/etc/nix/nix.custom.conf` で止まったら中身を確かめて消す) → `rm result` → 確認 (spec の scenario)。Determinate が残る Mac で誤って switch したときの `darwin-rebuild --rollback` も書く。ホストは役割の名前で書く
- [ ] 4.3 README の `darwinModules.default` の説明から「Nix の管理の無効化 (Determinate Nix 前提)」を除き、Nix の設定 (flakes の有効化、channel の無効化) を nix-darwin が管理する旨に改める。「利用側が与えるもの」に、その Mac に Determinate ではない Nix が入っていることを足す
- [ ] 4.4 `CLAUDE.md` の「`nix search nixpkgs` は `flake.lock` を見ていない」の項を削る。「`darwin-rebuild` は呼び出し側の PATH に依存しない」の項を、`nix` が `nix.package` の store パスから解決され、`/nix/var/nix/profiles/default/bin` は予備になったことに合わせて直す
- [ ] 4.5 `grep -rni` で `determinate`、`flakehub`、`nixpkgs-weekly`、`extra-nix-path`、`nix.custom.conf`、`id-token` を検索する (`openspec/changes/` を除く)。残ってよいのは、入れ替えの手順、system-bootstrap と config-validation の要件の文、`modules/darwin/default.nix` の前提のコメントだけであることを確かめる

## 5. 確認 (利用側で、手元のクローンを指して。switch はしない)

- [ ] 5.1 `--override-input core path:../dotfiles` で各ホストを評価と build する
- [ ] 5.2 1.1 と比べる: `environment.etc` に増えるのは `nix/nix.conf` と `nix/registry.json` だけ、`launchd.daemons` に増えるのは `nix-daemon` だけ、`environment.systemPackages` に増えるのは `nix` と `nix-info` だけ、home-manager の `home-files` と `home.path` の drvPath は変わらない。違いがあれば原因を記録する
- [ ] 5.3 build 結果の `etc/nix/nix.conf` に `experimental-features = nix-command flakes` があり、`etc/nix/registry.json` の `nixpkgs` が利用側の lock の nixpkgs の store パスを指していること、`set-environment` の `NIX_PATH` が `nixpkgs=flake:nixpkgs` だけであることを確かめる
- [ ] 5.4 あるホストに `nix.enable = lib.mkForce false` を与えた構成の toplevel の drvPath が、1.1 と一致することを確かめる (1 台ずつ移すときの回避策、design D5)
- [ ] 5.5 upstream の nix (lock の nixpkgs の `nix`) で、このリポジトリの `nix flake check --no-build --all-systems` と ci.yml の全ホストの評価を手元で実行し、存在しない option を書いた構成で後者だけが失敗することを確かめる

## 6. archive とマージ

- [ ] 6.1 利用側の禁止語の検査を、このブランチの全コミットと成果物に対して実行する
- [ ] 6.2 PR を作り、CI (ci.yml) が upstream の Nix で通ることを確かめる。PR の本文に、マージの後に行うこと (design の Migration Plan: `update-flake-lock.yml` の手動実行での確認と、各 Mac の入れ替え) はこの change の外で所有者が行うことを書く
- [ ] 6.3 `openspec archive use-upstream-nix` を実行し、archive した後に `openspec/specs/system-bootstrap/spec.md` の Purpose を、upstream の Nix を nix-darwin が管理する内容に書き換えてコミットする (delta では Purpose を変えられないため)
- [ ] 6.4 マージする
