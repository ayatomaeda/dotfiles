{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;

  # 署名プログラムのラッパー (remote-agent-forwarding)。ssh 越しのシェルでは
  # op-ssh-sign を使わず、転送された agent (SSH_AUTH_SOCK) で ssh-keygen が
  # 署名する。op-ssh-sign は自機の 1Password に問い合わせるため、そのままでは
  # 承認が接続先の画面に出て止まる。
  #
  # 判定は ssh の設定 (ssh.nix の 1Password の Match) と同じ条件で行う。転送された
  # agent を使うのは次のどちらかのとき (条件の理由は ssh.nix に書いてある)。
  #   (a) SSH_CONNECTION があり、転送ソケットが実在する (tmux の detach 後に残る古い値への対策)
  #   (b) SSH_AUTH_SOCK が固定パス ~/.ssh/agent-forward.sock で、その先が実在する
  #       (herdr のペイン。herdr-remote-machines。先は ssh/rc が張り替える)
  #
  # op-ssh-sign 自身も転送に対応しているが、SSH_TTY で判定するため
  # TTY なしの実行 (ssh host 'git commit ...') では失敗する (実測)。
  #
  # ssh-keygen -Y sign は、公開鍵 (git が user.signingkey から一時ファイルに
  # 書き出す) を渡されると SSH_AUTH_SOCK の agent で署名する。
  #
  # op-ssh-sign のパスは macOS 固有なので、使われるのは下の gate の内側だけ。
  signProgram = pkgs.writeShellScript "git-ssh-sign" ''
    if [ -S "$SSH_AUTH_SOCK" ] && { [ -n "$SSH_CONNECTION" ] || [ "$SSH_AUTH_SOCK" = "$HOME/.ssh/agent-forward.sock" ]; }; then
      exec /usr/bin/ssh-keygen "$@"
    fi
    exec /Applications/1Password.app/Contents/MacOS/op-ssh-sign "$@"
  '';
  # difftastic は PATH ではなく store パスで参照する。エージェントと人間で
  # PATH が違う可能性があるため、alias の指し先を環境に依存させない。
  difft = lib.getExe config.programs.difftastic.package;
in
{
  # 差分表示は 2 つを役割で分ける (modernize-terminal-env)。
  #
  #   delta      : git のページャ (pager.diff / log / show / blame) と
  #                interactive.diffFilter。git が非 TTY でページャを無効化するため、
  #                Claude Code のような非対話エージェントの `git diff` は
  #                素の unified diff のまま変わらない (実測済み)。
  #   difftastic : `git dft` でのみ呼ぶ。構文木ベースなので再インデントを
  #                差分として数えず、lib.mkIf / lib.optionals で既存ブロックを
  #                包む変更 (このリポジトリで頻出) が劇的に読みやすくなる。
  #                実測: git.nix を mkIf で包んだ差分が delta 51 行 -> 9 行。
  #
  # **difftastic を diff.external に置かない。** diff.external は TTY と無関係に
  # 起動するため、エージェントが読む `git diff` の形式まで変わる。加えて
  # `git log -p -15` で delta の 3.7 倍遅い (0.73s / 2.70s)。
  programs.delta = {
    enable = true;
    # 既定は false。有効にすると core.pager / pager.blame /
    # interactive.diffFilter がまとめて設定される。
    enableGitIntegration = true;
  };
  programs.difftastic = {
    enable = true;
    # 上記のとおり diff.external を設定させない。git.mode = "difftool" も
    # 使えない — programs.git の assertion が delta の git 統合と排他にして
    # おり、difftool 経由は `File permissions changed from ...` を出力に混ぜる。
    # したがってパッケージの導入にだけ native モジュールを使い、呼び出しは
    # 下の alias で行う。
    git.enable = false;
  };

  # git を native モジュール化。
  #
  # identity は core に書かない。利用側が programs.git.settings.user.{name,email} を
  # 与え、モジュールシステムがここの settings とマージする (split-public-core)。
  # 署名鍵は git.nix が読む値なので option にしてある (dotfiles.git.signingKey)。
  programs.git = {
    enable = true;

    # `//` は浅いマージであり、右辺の user.signingkey が左辺の user 全体を
    # 置き換えて user.* のほかの値を消してしまう。recursiveUpdate を使う。
    settings = lib.recursiveUpdate
      {
        init.defaultBranch = "main";
        ghq.root = "~/git";
        # GitHub はマージ後にブランチを自動で削除する (リポジトリの設定)。
        # fetch / pull のたびに、消えたブランチの origin/… を片付ける。
        # 消えるのはリモート追跡ブランチだけで、ローカルのブランチとタグは残る
        # (タグも消す fetch.pruneTags は設定しない)。
        fetch.prune = true;
        # difftastic を明示的に呼ぶための alias。`-c` を前置した非シェル
        # alias であり、`git dft --stat` のように引数がそのまま後ろへ渡る。
        # 素の `git diff` は影響を受けない (いずれも実測で確認)。
        alias.dft = "-c diff.external=${difft} diff";
      }
      # 1Password による署名。macOS 固有の実行パスを含むため、使うホストにのみ
      # 宣言する。false のホスト、または鍵を与えられていない利用側では、署名設定
      # 自体を出力しない (commit.gpgsign だけが入るとコミットが失敗する)。
      (lib.optionalAttrs (cfg.onePassword.enable && cfg.git.signingKey != null) {
        # 公開鍵を直接書く形式。git は "ssh-" で始まる素の文字列も受け付けるが、
        # その形式は非推奨とされている (git-config(1) user.signingKey)。
        user.signingkey = "key::${cfg.git.signingKey}";
        gpg.format = "ssh";
        gpg."ssh".program = "${signProgram}";
        commit.gpgsign = true;
      });
  };
}
