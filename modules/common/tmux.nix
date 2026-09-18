{ config, ... }:
let
  tmux = "${config.programs.tmux.package}/bin/tmux";
in
{
  programs.tmux = {
    enable = true;

    # 既定の mouse off ではホイールが copy-mode に届かず、スクロールできない。
    # ホイールの割り当て自体は tmux 3.7 の既定で足りている (vim / less の中では
    # アプリへ渡し、それ以外では copy-mode -e に入る)。古い記事にある
    # bind WheelUpPane や tmux-better-mouse-mode は不要。
    mouse = true;
    historyLimit = 50000;

    # home-manager の既定は "screen" で、tmux 内では 256 色も斜体も使えない。
    # terminfo は Nix のプロファイル (TERMINFO_DIRS) にあるので macOS 同梱の
    # ncurses でも解決できる。
    terminal = "tmux-256color";

    # tmux 単体なら EDITOR=nvim から vi を自動選択するが、home-manager の既定
    # ("emacs") がそれを上書きしている。neovim と操作を揃える。
    keyMode = "vi";

    extraConfig = ''
      # keyMode は status-keys も vi にする。コマンドプロンプト (prefix :) の
      # 行編集はシェルと同じ emacs 式のままにしておく。
      set -g status-keys emacs

      # copy-mode の間だけスクロールバーを出す (tmux 3.6+)。
      set -g pane-scrollbars modal

      # vi 既定では v が矩形選択の切替で、y は未割り当て。neovim に合わせる。
      bind -T copy-mode-vi v   send -X begin-selection
      bind -T copy-mode-vi C-v send -X rectangle-toggle
      bind -T copy-mode-vi y   send -X copy-pipe-and-cancel

      # 既定の copy-pipe-and-cancel はドラッグを離した時点で copy-mode を抜け、
      # 遡っていたスクロール位置が一番下へ戻る。コピーだけして留まる。
      bind -T copy-mode-vi MouseDragEnd1Pane send -X copy-pipe-no-clear

      # プロンプト単位の移動。シェルが OSC 133 を出している必要がある
      # (terminal.nix で Ghostty のシェル統合を tmux 内でも読み込んでいる)。
      bind -T copy-mode-vi [ send -X previous-prompt
      bind -T copy-mode-vi ] send -X next-prompt

      # attach とセッションの切り替えを zsh の preexec に知らせる目印
      # (下の _tmux_refresh_ssh_env)。どちらもセッションの環境を更新する。
      # フックの文字列は設定の読み込み時と実行時の 2 回解釈される。読み込み時の
      # 二重引用符の中では \$ と \" がそのまま $ と " になり、実行時の単一引用符の
      # 中では tmux が $ を展開しないので、$$ は sh に届く。#{socket_path} は
      # run-shell が展開する。
      set-hook -g client-attached "run-shell 'echo \$\$ > \"#{socket_path}.attached\"'"
      set-hook -g client-session-changed "run-shell 'echo \$\$ > \"#{socket_path}.attached\"'"
    '';
  };

  # tmux の既存ペインで、ssh 由来の環境変数を最新に保つ (remote-agent-forwarding)。
  #
  # tmux は attach のたびに update-environment (既定で SSH_AUTH_SOCK /
  # SSH_CONNECTION を含む) をセッションの環境へ反映するが、既に動いている
  # ペインのシェルには反映しない。そのままだと、接続先の Mac の前で起動したペインに
  # 接続元の Mac から attach しても SSH_CONNECTION が空のままで、ssh と署名が接続先の
  # 1Password を使い、承認が無人の画面に出る (ssh.nix の 1Password の Match)。
  # attach (またはセッションの切り替え) の後の最初のコマンドの前に、
  # セッションの環境から読み直す。
  #
  # **attach / 切り替えがあったときだけ tmux を呼ぶ。** tmux の起動は 1 回
  # 約 9ms かかり、毎回 2 変数を読むとコマンドのたびに約 18ms 遅れていた (実測)。
  # client-attached / client-session-changed フックがソケットの隣の目印ファイルへ
  # 書き込み、preexec はその中身を組み込みの read で見るだけにする (fork しない)。
  # - 更新時刻ではなく中身を比べる。更新時刻は秒単位なので、コマンドの直後の
  #   同じ秒に起きた attach を見落とす。中身は run-shell の sh の PID で、
  #   続けて同じ値になることはない。
  # - シェルの起動時にも読んでおく。新しいペインは作られた時点のセッションの
  #   環境を受け継ぐので、それより前の attach で読み直す必要はない。
  # - update-environment が反映されるのは、セッションの作成・attach・
  #   switch-client (-E なし) のとき。prefix s / ( / ) も switch-client を通る
  #   ので、client-session-changed も拾う。拾わないと、ssh 越しの環境を
  #   読んだペインへローカルのクライアントから切り替えたときに古い値が残り、
  #   承認が接続元の Mac に出る。detach では環境は変わらない。
  #
  # tmux は detach のときに環境を戻さない。ssh で attach して切断した後は、
  # 古い SSH_CONNECTION と消えたソケットが残るが、ssh の設定と署名ラッパーが
  # ソケットの実在も見るので、自機の 1Password に戻る。
  #
  # show-environment -s は、値があれば export、セッションから消えていれば
  # unset のシェル文を出す。一度も設定されていない変数はエラーになり何も
  # 出力しないので、そのときは何もしない。
  #
  # **Claude Code のシェルには効かない。** シェルスナップショットは関数を保存
  # するが、preexec_functions (配列) を保存しない (CLAUDE.md)。attach し直す前から
  # 動いているプロセスは古い環境のままなので、attach 後に起動し直す。
  #
  # 目印ファイルを書くフックは extraConfig にある。フックの定義は tmux の設定を
  # 読み直したときに反映されるので、既に動いているサーバーには
  # `tmux source-file ~/.config/tmux/tmux.conf` が要る。
  programs.zsh.initContent = ''
    if [[ -n "$TMUX" ]]; then
      _tmux_attached_file="''${TMUX%%,*}.attached"
      _tmux_attached_seen=
      [[ -r $_tmux_attached_file ]] && read -r _tmux_attached_seen < $_tmux_attached_file
      _tmux_refresh_ssh_env() {
        local _stamp= _v _line
        [[ -r $_tmux_attached_file ]] || return 0
        read -r _stamp < $_tmux_attached_file
        [[ $_stamp == $_tmux_attached_seen ]] && return 0
        _tmux_attached_seen=$_stamp
        for _v in SSH_AUTH_SOCK SSH_CONNECTION; do
          _line=$(${tmux} show-environment -s "$_v" 2>/dev/null) && eval "$_line"
        done
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook preexec _tmux_refresh_ssh_env
    fi
  '';
}
