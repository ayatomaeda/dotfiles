{ config, lib, pkgs, ... }:
let
  cfg = config.dotfiles;

  onePasswordPaths = import ./one-password.nix;

  # 転送された agent (SSH_AUTH_SOCK) を使うかの判定 (remote-agent-forwarding)。
  # 下の署名のラッパーと鍵を選ぶスクリプトが、この 1 つの文字列を埋め込んで共有する。
  # 転送された agent を使うのは次のどちらかのとき (条件の理由は ssh.nix に書いてある)。
  #   (a) SSH_CONNECTION があり、転送ソケットが実在する (tmux の detach 後に残る古い値への対策)
  #   (b) SSH_AUTH_SOCK が固定パス ~/.ssh/agent-forward.sock で、その先が実在する
  #       (herdr のペイン。herdr-remote-machines。先は ssh/rc が張り替える)
  #
  # 条件と固定パスをそろえる場所は 4 か所: ここ、ssh.nix の 1Password の Match
  # (否定形で引用の文脈も違うので別に書く)、ssh/rc、terminal.nix。
  isForwarded = ''[ -S "$SSH_AUTH_SOCK" ] && { [ -n "$SSH_CONNECTION" ] || [ "$SSH_AUTH_SOCK" = "$HOME/.ssh/agent-forward.sock" ]; }'';

  # 署名プログラムのラッパー (remote-agent-forwarding)。ssh 越しのシェルでは
  # op-ssh-sign を使わず、転送された agent (SSH_AUTH_SOCK) で ssh-keygen が
  # 署名する。op-ssh-sign は自機の 1Password に問い合わせるため、そのままでは
  # 承認が接続先の画面に出て止まる。
  #
  # op-ssh-sign 自身も転送に対応しているが、SSH_TTY で判定するため
  # TTY なしの実行 (ssh host 'git commit ...') では失敗する (実測)。
  #
  # ssh-keygen -Y sign は、公開鍵 (git が下の keyCommand の出力から一時ファイルに
  # 書き出す) を渡されると SSH_AUTH_SOCK の agent で署名する。秘密鍵のファイルは要らない。
  #
  # op-ssh-sign のパスは macOS 固有なので、使われるのは下の gate の内側だけ。
  signProgram = pkgs.writeShellScript "git-ssh-sign" ''
    if ${isForwarded}; then
      exec /usr/bin/ssh-keygen "$@"
    fi
    exec ${onePasswordPaths.signProgram} "$@"
  '';

  # 署名鍵を選ぶスクリプト (select-signing-key-by-name)。git が gpg.ssh.defaultKeyCommand
  # として署名のたびに実行し、出力の 1 行目 (`key::<種類> <本体>`) を署名鍵にする。
  #
  # 1Password の SSH agent は、鍵のコメントとして項目名を返す (項目名を変えると
  # コメントもすぐ変わる。実測)。ssh-add -L の各行の、種類と本体を除いた残り全体を
  # dotfiles.git.signingKeyName と完全一致で比べ、一致がちょうど 1 本のときだけ使う。
  # 項目名は空白を含みうるので 3 列目だけを見ない。部分一致・正規表現を使わない。
  # 先頭の鍵を使わないのは、1Password は新しい鍵を一覧の先頭に出すため (実測)。
  # 鍵を 1 本足しただけで、登録していない鍵で黙って署名することになる。
  #
  # agent は署名のラッパーと同じ判定で選ぶ。手元の SSH_AUTH_SOCK は launchd の空の
  # agent なので、ssh 越しでなければ 1Password のソケットを直接見る。
  #
  # op CLI を使わない。サインインの状態に依存し、ssh 越しでは接続先の 1Password に
  # 問い合わせ、Claude Code のシェルからは CLI 連携が効かない (実測)。ssh-add -L は
  # 一覧を取るだけで、1Password の承認は出ない (ロック中も出ない)。
  #
  # git はこのコマンドをシェルを通さずに実行する (引数を渡せず、$HOME も展開されない。
  # 実測)。そこで名前は Nix の側でスクリプトの本文に埋め込み、$HOME はスクリプトの中で
  # 展開する。defaultKeyCommand には store パスだけを書く。
  #
  # 失敗したときは非 0 で終わり、git はコミットを作らない。git の最後の行
  # (user.signingKey needs to be set) を見て user.signingkey を設定すると、この仕組みを
  # 黙って迂回するので、どのメッセージにもそれをしないよう添える。
  keyCommand = pkgs.writeShellScript "git-ssh-signing-key" ''
    name=${lib.escapeShellArg (toString cfg.git.signingKeyName)}

    if ${isForwarded}; then
      forwarded=1
      sock=$SSH_AUTH_SOCK
      agent="転送された agent ($sock)"
    else
      forwarded=
      sock="$HOME/${onePasswordPaths.agentSocket}"
      agent="この Mac の 1Password の agent ($sock)"
    fi

    fail() {
      {
        printf 'git-ssh-signing-key: %s\n' "$1"
        printf '  名前: %s\n' "$name"
        printf '  見た agent: %s\n' "$agent"
        if [ -n "$2" ]; then printf '  %s\n' "$2"; fi
        printf '  user.signingkey を設定して回避しないこと (名前による鍵の選択が黙って外れる)。\n'
      } >&2
      exit 1
    }

    err=$(${pkgs.coreutils}/bin/mktemp)
    trap '${pkgs.coreutils}/bin/rm -f "$err"' EXIT
    keys=$(SSH_AUTH_SOCK=$sock /usr/bin/ssh-add -L 2>"$err")
    status=$?

    case $status in
      0) ;;
      1)
        # 鍵が 1 本も無いとき、ssh-add は案内文を標準出力に出して 1 で終わる。
        # 案内文を鍵の行として読まない。それ以外の 1 は通信の失敗 (下の汎用のメッセージ)。
        if [ "$keys" = "The agent has no identities." ]; then
          if [ -n "$forwarded" ]; then
            fail "agent に鍵が 1 本も無いので、その名前の鍵が無い。" \
              "接続元で agent を転送しているか (ForwardAgent) を確かめる。"
          else
            fail "agent に鍵が 1 本も無いので、その名前の鍵が無い。" \
              "1Password のロックを解除し、SSH agent の設定を確かめる。"
          fi
        fi
        fail "ssh-add -L が終了コード 1 で失敗した: $(<"$err")"
        ;;
      2)
        if [ -n "$forwarded" ]; then
          fail "agent に接続できない。" "転送の接続が切れていないかを確かめる。"
        else
          fail "agent に接続できない。" "1Password が起動しているかを確かめる。"
        fi
        ;;
      *)
        fail "ssh-add -L が終了コード $status で失敗した: $(<"$err")"
        ;;
    esac

    found=
    count=0
    while IFS= read -r line; do
      type=''${line%% *}
      rest=''${line#* }
      [ "$rest" = "$line" ] && continue # 空白の無い行
      body=''${rest%% *}
      [ "$body" = "$rest" ] && continue # コメントの無い鍵
      comment=''${rest#* }
      if [ "$comment" = "$name" ]; then
        found="key::$type $body"
        count=$((count + 1))
      fi
    done <<<"$keys"

    case $count in
      1) printf '%s\n' "$found" ;;
      0) fail "agent にその名前の鍵が無い。" \
           "1Password の項目名と dotfiles.git.signingKeyName が一致しているかを確かめる (ロック中は解除前の一覧が返る)。" ;;
      *) fail "agent にその名前の鍵が $count 本ある。どれでも署名しない。" \
           "同じ名前の項目を 1 つにする (使わない方の名前を変える)。" ;;
    esac
  '';

  # 署名の設定を出力するか。1Password を使わないホスト、または名前を与えない利用側では
  # 出力しない (commit.gpgsign だけが入るとコミットが失敗する)。
  signing = cfg.onePassword.enable && cfg.git.signingKeyName != null;

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
  # 署名鍵の名前は git.nix が読む値なので option にしてある (dotfiles.git.signingKeyName)。
  programs.git = {
    enable = true;

    # `//` は浅いマージであり、右辺に左辺と同じ節 (user など) があると左辺のその節
    # 全体を置き換えて、ほかの値を消してしまう。recursiveUpdate を使う。
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
      # 宣言する。false のホスト、または名前を与えられていない利用側では、署名設定
      # 自体を出力しない (上の signing)。
      #
      # user.signingkey は書かない。git は user.signingkey が無いときだけ
      # defaultKeyCommand を実行し、その出力を署名鍵にする (実測)。
      (lib.optionalAttrs signing {
        gpg.format = "ssh";
        gpg."ssh".program = "${signProgram}";
        gpg."ssh".defaultKeyCommand = "${keyCommand}";
        commit.gpgsign = true;
      });
  };

  # 利用側が user.signingkey を宣言すると、git は defaultKeyCommand を使わなくなり、
  # 名前による選択が黙って外れる。宣言の書き方は次の 3 つの場所に現れる。
  #   - programs.git.settings.user.signingkey (iniContent に入る)
  #   - programs.git.signing.key (home-manager が iniContent.user.signingKey に書く)
  #   - programs.git.includes の contents (別ファイルになり、[include] / [includeIf] で
  #     読まれるので iniContent には現れない。home-manager の例がまさにこの形)
  # git のセクション名とキーは大文字小文字を区別しないので、小文字にして比べる。
  # 検出できないのは、includes の path で読む既存のファイルと、宣言の外
  # (~/.gitconfig、.git/config)。
  #
  # 署名の設定を出力しないホストでは止めない。そこで利用側が自分の user.signingkey を
  # 使っても、この仕組みを迂回したことにはならない。
  assertions =
    let
      declaresSigningKey =
        sections:
        lib.any (
          section:
          lib.toLower section == "user"
          && lib.isAttrs sections.${section}
          && lib.any (key: lib.toLower key == "signingkey") (lib.attrNames sections.${section})
        ) (lib.attrNames sections);
    in
    lib.optional signing {
      assertion =
        !(declaresSigningKey config.programs.git.iniContent)
        && !(lib.any (include: declaresSigningKey include.contents) config.programs.git.includes);
      message = ''
        dotfiles.git.signingKeyName を与えた構成で user.signingkey が宣言されている。
        git は user.signingkey があると名前で鍵を選ばなくなるので、
        programs.git.settings.user.signingkey (大文字小文字を問わない)、
        programs.git.signing.key、programs.git.includes の contents.user.signingkey の
        宣言を消す。
      '';
    };
}
