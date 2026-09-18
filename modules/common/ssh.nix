# ssh クライアントの設定 (~/.ssh/config) と、sshd が実行する ~/.ssh/rc。
#
# 以前は ssh/config と ssh/config.d/*.conf の生ファイルを out-of-store symlink で
# 置き、Include で読ませていた。宣言から生成する形に変えたので
# (retire-out-of-store-symlinks)、config.d と Include は無くなり、
# ~/.ssh/config 1 枚が store のコピーとして置かれる。
#
# **ブロックの順序に意味がある。** ssh は同じキーワードの**最初の値**を採るので、
# ホスト個別の値は `Host *` より前になければならない (github.com の
# ControlMaster no と `Host *` の ControlMaster auto)。settings."*" は
# home-manager が必ず最後に出力する (defaultHostBlock を並べ替えの後ろに付ける)。
# それ以外のブロックは属性名の昇順に出るが、互いに重なるキーワードを持たない。
{ config, lib, ... }:
let
  cfg = config.dotfiles;
in
{
  programs.ssh = {
    enable = true;

    # **既定値を引き継がない。** 既定 (true) では home.manager が settings."*" に
    # ForwardAgent no / AddKeysToAgent no / Compression no / ServerAliveInterval 0 /
    # HashKnownHosts no / UserKnownHostsFile ~/.ssh/known_hosts / ControlMaster no …
    # を注入し、さらに「将来削除される」旨の警告を毎回出す。移行前の ssh/config は
    # これらを 1 つも設定していない。とくに UserKnownHostsFile は ssh 組み込みの
    # 既定 (~/.ssh/known_hosts と ~/.ssh/known_hosts2 の 2 つ) を置き換えてしまう。
    enableDefaultConfig = false;

    # package の既定は null。openssh は入れず、macOS 同梱のものを使う (従来どおり)。

    settings = {
      # --- ホストごとの設定 ---
      #
      # 接続先は利用側が programs.ssh.settings.<host> に書く (split-public-core)。
      # 利用側のブロックも、下の規則のとおり属性名の昇順で `Host *` より前に出る。
      #
      # Host 行に書いた名前 (ワイルドカードを含まないもの) は zsh の補完
      # (_ssh_hosts) の候補になる。_ssh_hosts は ~/.ssh/config を読むが
      # known_hosts は読まない。

      "github.com" = {
        User = "git";
        # 多重化しない。`Host *` の ControlMaster auto より前に出る必要がある。
        ControlMaster = "no";
      };

      # --- 全ホスト共通 (旧 10-canonicalize.conf + 90-general.conf) ---
      #
      # 2 つの `Host *` ブロックを 1 つにまとめた。重なるキーワードが無いので
      # ssh から見た実効値は変わらない (ssh -G で確認済み)。
      "*" = {
        CanonicalizeHostname = true;
        CanonicalizeFallbackLocal = true;

        PreferredAuthentications = "publickey";
        ControlMaster = "auto";
        ControlPath = "~/.ssh/%C.sock";
        ControlPersist = "10s";
      };
    }
    # --- 1Password の SSH agent (旧 95-1password.conf) ---
    #
    # 以前はファイル名の文字列一致で配置を出し分けていた (files.nix の
    # onePasswordConf と、それを守る assertions)。option で直接分岐できるように
    # なったので、どちらも要らなくなった。
    // lib.optionalAttrs cfg.onePassword.enable {
      # 1Password の SSH agent を認証に使う。macOS 固有のパスを含むため、
      # 1Password を動かすホストにのみ出力する。
      # 同じ鍵が git の署名にも使われる (modules/common/git.nix の署名ラッパー)。
      #
      # ssh 越しのシェルでは適用しない (remote-agent-forwarding)。IdentityAgent は
      # SSH_AUTH_SOCK を上書きするため、無条件に置くと転送された agent が使われず、
      # 承認が接続先の画面に出て止まる。次のどちらかのときは適用しないので、ssh は
      # 既定どおり SSH_AUTH_SOCK (転送された agent) を使う。
      #   (a) SSH_CONNECTION があり、転送ソケットが実在する (ssh 越しのシェル、tmux)
      #   (b) SSH_AUTH_SOCK が固定パス ~/.ssh/agent-forward.sock で、その先が実在する
      #       (herdr のペイン。herdr-remote-machines。先は ssh/rc が張り替える)
      # 条件は git.nix の署名ラッパーとそろえる。
      #
      # - (b) で SSH_CONNECTION を見ないのは、接続先の Mac の前で起動した herdr の
      #   サーバーのペインには SSH_CONNECTION が無いため。固定パスとの一致を見るのは、ローカルの
      #   シェルの SSH_AUTH_SOCK (launchd のソケット) も実在するため。
      # - [ -S ] は symlink の先をたどる。接続が切れて先が消えていれば 1Password に戻る。
      # - ソケットの実在も見るのは、tmux が detach で環境を戻さないため。ssh で attach
      #   して切断した後も、セッションの環境 (と新しいペイン、tmux.nix のフック) には
      #   古い SSH_CONNECTION と消えたソケットが残る。sshd は切断時にソケットを消すので、
      #   無ければ 1Password に戻す。
      # - 公式の例は SSH_TTY で判定するが、TTY なしの実行 (ssh host 'git ...') では
      #   空になり誤判定する。
      # - $SSH_CONNECTION は引用符で囲む。Match exec は $SHELL (未設定なら /bin/sh)
      #   で実行され、sh / bash では空白区切りの値が分割されて [ がエラーを出す。
      #
      # header に書くのは、条件が属性名にできないため (引用符とバックスラッシュを含む)。
      onePassword = {
        header = ''Match host * exec "[ ! -S \"$SSH_AUTH_SOCK\" ] || { [ -z \"$SSH_CONNECTION\" ] && [ \"$SSH_AUTH_SOCK\" != \"$HOME/.ssh/agent-forward.sock\" ]; }"'';
        # 値に空白を含むので、生成される行でも引用符で囲む必要がある。
        IdentityAgent = ''"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';
      };
    };
  };

  # sshd がログインのたびに (コマンドを実行する接続も含めて) 実行する (sshd(8) の SSHRC)。
  # 転送された agent のソケットへ固定パスの symlink を張り替える
  # (herdr-remote-machines)。sshd は sh で読むので実行可能属性は要らない。
  #
  # **中身はリポジトリのファイルのまま store へコピーする。** シェルスクリプトを
  # Nix の文字列に埋め込むと $ のエスケープだらけになるため。out-of-store symlink
  # とは違い、rebuild しないと反映されない。
  home.file.".ssh/rc".source = ../../ssh/rc;
}
