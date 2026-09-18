{ lib, ... }:
{
  # 端末作業のための道具。home-manager に programs.* native モジュールが
  # あるものはすべてそれで宣言し、home.packages には重複して置かない
  # (terminal-tooling: 端末ツールは native モジュールで宣言する)。
  # initContent への手書きの初期化 (eval "$(... init zsh)") も書かない。
  #
  # 導入の根拠は、この端末で実際に起きている作業に置く。この端末は人間と
  # Claude Code が同じシェル構成を共有しており、**主な使い手は非対話の
  # エージェント**である。そのため一般的な「モダン端末」構成のうち打鍵量を
  # 減らすもの (autosuggestions / abbr / atuin) は採らず、
  #   (1) エージェントが呼ぶコマンドが PATH にあること
  #   (2) 人間がエージェントの出力を読めること
  #   (3) 人間がたまに打つ操作 (移動・状態把握) の摩擦
  # に配分している (modernize-terminal-env)。

  # (1) エージェントが走る — PATH に道具があるか

  # claude/statusline-command.sh が呼ぶ。宣言しないと macOS 同梱の
  # /usr/bin/jq に落ち、flake の pin の外にある版で動くことになる。
  programs.jq.enable = true;

  # rg はこれまでシェルに存在せず、Claude Code が注入する shell function
  # としてのみ存在していた (対話シェルからは実行できなかった)。
  # arguments を空のままにしてあるので RIPGREP_CONFIG_PATH は設定されない。
  programs.ripgrep.enable = true;

  programs.fd.enable = true;

  # (2) 人間がエージェントの出力を読む

  # ページャ付きで構文強調して読むため。**ls / cat の alias にはしない** —
  # programs.zsh.shellAliases の宣言は Claude Code のシェルスナップショット
  # (~/.claude/shell-snapshots/*.sh) にそのまま載るため、既存コマンド名を
  # 乗っ取ると非対話エージェントの実行に波及する (terminal-tooling)。
  programs.bat.enable = true;

  # git の差分表示 (delta / difftastic) は git.nix にまとめてある。
  # どちらも「git diff をどう読むか」のための道具であり、単体では使わない。

  # (3) 人間がたまに打つ — 移動

  # Ctrl-R (履歴) / Ctrl-T (ファイル) / Alt-C (ディレクトリ) を提供する。
  # シェル統合は enableZshIntegration が既定で有効。initContent に
  # eval "$(fzf --zsh)" を手書きしない。
  programs.fzf = {
    enable = true;
    defaultOptions = [
      "--height=40%"
      "--layout=reverse"
      "--border"
    ];
  };

  # cd の置き換え (z)。これも初期化は native モジュールが書く。
  programs.zoxide.enable = true;

  # ghq + fzf の組み合わせだけは programs.* で表現できないため initContent に
  # 置く。~/git に 30 リポジトリあり、リポジトリ間の移動が人間側の主な操作で
  # あるため (terminal-tooling: native モジュールが無いツールは理由を残した
  # うえで initContent に記述する)。
  #
  # zoxide の z は「一度訪れた場所へ戻る」ためのもので、まだ訪れていない
  # リポジトリには効かない。ghq list はその補集合を埋める。
  programs.zsh.initContent = lib.mkMerge [
    ''
      # ghq 管理下のリポジトリを fzf で選んで移動する。
      __ghq_fzf_cd() {
        local dir
        dir=$(ghq list --full-path | fzf --query "$LBUFFER") || {
          zle redisplay
          return 0
        }
        # (q) は zsh のクォート展開。パスに空白が含まれても壊れない。
        BUFFER="cd ''${(q)dir}"
        # 実行して履歴にも残す。あとから同じ移動を辿れるようにするため。
        zle accept-line
      }
      zle -N __ghq_fzf_cd
      bindkey '^g' __ghq_fzf_cd
    ''

    (lib.mkOrder 1400 ''
      # 実行したプロンプトを zsh の既定の表示に置き換える (transient prompt)。
      #
      # starship の transient prompt は zsh では提供されない。home-manager の
      # programs.starship.enableTransience も「This is only a valid option for the
      # Fish shell」。そのため zsh 側で補う (terminal-tooling: native モジュールが
      # 対象シェルで提供しない機能の補完)。
      #
      # starship の初期化 (initContent の既定の順序 1000) より後に置くため mkOrder 1400。
      # Ghostty のシェル統合の読み込み (1500) より前にして、順序をリストの書き順に頼らない。
      # starship が PROMPT を代入した値を控えて包むだけで、プロンプトの内容を別に
      # 定義してはいない (dotfiles-management: 定義元を 2 つにしない)。
      # starship が初期化されない条件 (TERM=dumb) では何もしない。
      if [[ $TERM != "dumb" && $PROMPT == *starship* ]]; then
        # 記号は zsh 既定の %# (通常 %、root なら #)。色は付けない — 終了ステータスで
        # 緑 / 赤に塗る形を実際に使ったところ鬱陶しかった (所有者)。失敗は下の exit N で示す。
        __prompt_mark='%# '
        # 実行後の行: macOS 同梱 zsh の既定 PS1 (/etc/zshrc.before-nix-darwin) と同じ形。
        __prompt_past_line="%n@%m %1~ $__prompt_mark"
        # starship init zsh は PROMPT / RPROMPT を 1 回だけ代入する。その値を控える。
        __prompt_full="$PROMPT"$'\n'"$__prompt_mark"
        __prompt_full_right=$RPROMPT
        PROMPT=$__prompt_full

        # Ghostty のシェル統合が読み込まれているとき (tmux のペインを含む) は、置き換えた行にも
        # 統合と同じ OSC 133 の印 (プロンプトの始まり A / 入力の始まり B) を付ける。付けないと
        # 描き直した行がプロンプトとして認識されず、tmux の previous-prompt が過去のコマンドを
        # 飛ばす (実測: 置き換えなしでは 3 回とも 1 つ前のプロンプトへ、置き換えありでは
        # 2 回目で先頭まで飛んだ)。
        __prompt_to_past_line() {
          if (( $+_ghostty_state )); then
            PROMPT=$'%{\e]133;A;cl=line%}'"$__prompt_past_line"$'%{\e]133;B%}'
          else
            PROMPT=$__prompt_past_line
          fi
          RPROMPT=""
          zle .reset-prompt
        }
        zle -N zle-line-finish __prompt_to_past_line

        # 元に戻すのは precmd。zle-line-finish の中で戻すと、zsh は描き直しを widget を
        # 抜けた後に行うため、戻した後の値で描かれて置き換わらない (実測)。
        __prompt_restore() {
          PROMPT=$__prompt_full
          RPROMPT=$__prompt_full_right
          __prompt_define_trapint
        }

        # 入力途中の Ctrl-C は zle-line-finish を通らないため、TRAPINT でも置き換える (実測)。
        # direnv のフック (_direnv_hook) は precmd / chpwd のたびに `trap - SIGINT` を実行し、
        # これで関数の TRAPINT も消える (実測: 最初のプロンプトの時点で whence -w TRAPINT が
        # none)。そのため precmd のたびに定義し直す。_direnv_hook は precmd_functions の
        # 先頭に入るので、このフックより先に走る。
        #
        # 関数は Claude Code のシェルスナップショットに保存され、非対話のエージェントの
        # シェルでも TRAPINT が定義される。そのまま 130 を返すと、SIGINT での中断が
        # 「シグナルで終了」ではなく「終了コード 130 で終了」に変わる (実測)。
        # 非対話のシェルでは TRAPINT を外して SIGINT を送り直し、既定の動作に戻す
        # (terminal-tooling: 対話シェル向けの変更を非対話実行へ波及させない)。
        # 対話シェルで送り直すと、実行中のコマンドを止めたときの $? が 130 ではなく 1 に
        # なる (実測) ため、対話シェルでは 128 + シグナル番号を返す。
        __prompt_define_trapint() {
          TRAPINT() {
            if zle; then
              __prompt_to_past_line
              return $(( 128 + $1 ))
            fi
            if [[ -o interactive ]]; then
              return $(( 128 + $1 ))
            fi
            unfunction TRAPINT
            kill -INT $$
          }
        }

        # コマンドが実行されたか、バックグラウンドかを preexec で記録する。
        # 空の Enter と `&` / `&!` で起動したコマンドでは $pipestatus が更新されず、
        # 前のコマンドの値が残るため (実測)。
        __prompt_ran=0
        __prompt_background=0
        __prompt_mark_command() {
          local -a words=(''${(z)1})
          __prompt_ran=1
          [[ ''${words[-1]} == ('&'|'&!'|'&|') ]] && __prompt_background=1 || __prompt_background=0
        }

        # 失敗したときだけ、実行結果の直後に終了ステータスを残す。$? ではなく starship が
        # 退避した値を使う — 先に走った precmd のフックが $? を上書きするため。
        __prompt_exit_line() {
          (( __prompt_ran )) || return 0
          __prompt_ran=0
          (( __prompt_background )) && return 0
          local -a codes=(''${=STARSHIP_PIPE_STATUS})
          if (( ''${#codes} > 1 )); then
            [[ ''${codes[*]} == *[1-9]* ]] && print -P "%F{red}exit ''${(j:|:)codes}%f"
          elif (( ''${STARSHIP_CMD_STATUS:-0} != 0 )); then
            print -P "%F{red}exit ''${STARSHIP_CMD_STATUS}%f"
          fi
        }

        autoload -Uz add-zsh-hook
        add-zsh-hook preexec __prompt_mark_command
        add-zsh-hook precmd __prompt_restore
        add-zsh-hook precmd __prompt_exit_line
        __prompt_define_trapint
      fi
    '')

    # herdr のペインでは、転送された agent を固定パスで参照する (下の (5) herdr の節)。
    ''
      if [[ -n $HERDR_PANE_ID ]]; then
        export SSH_AUTH_SOCK="$HOME/.ssh/agent-forward.sock"
      fi
    ''

    # Ghostty のシェル統合は Ghostty が直接起動したシェルにしか自動で読み込まれず、
    # tmux のペインでは OSC 133 (プロンプト位置の印) が出ない (実測で 0 件)。
    # それが無いと tmux の previous-prompt / next-prompt が何もしない (tmux.nix)。
    # Ghostty が直接起動したシェルでは統合側の初期化済み判定で二重読み込みにならない。
    # starship の初期化より後に置く (実測した順序に合わせる)。
    (lib.mkOrder 1500 ''
      if [[ -n $GHOSTTY_RESOURCES_DIR ]]; then
        source "$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
      fi
    '')
  ];

  # (4) 環境の自動切替と状態把握

  # ディレクトリに応じて開発環境を切り替える。**このリポジトリが担当するのは
  # 「使える状態にする」までで、各プロジェクトの .envrc / flake.nix は
  # それぞれのリポジトリの仕事**である (terminal-tooling)。
  #
  # mise ではなく direnv + nix-direnv を採る。mise の売りは asdf + direnv +
  # make を 1 つにまとめる点だが、再現性の担保は既に flake が持っている。
  # mise を入れるとランタイムの版の真実が Nix と mise.toml の 2 箇所に分かれる
  # (modernize-terminal-env)。
  programs.direnv = {
    enable = true;
    # nix develop の結果をキャッシュし、再評価を避ける。
    nix-direnv.enable = true;
  };

  # プロンプト。見た目ではなく**状態把握**のために入れる。エージェントが
  # コマンドを実行したあと人間が知りたいのは「いまどこで、どのブランチで、
  # 直前の終了コードは何で、nix shell の中か」であり、素の
  # PROMPT="%n@%M %1~ %# " はそのどれも示さない (modernize-terminal-env)。
  #
  # 形は所有者が比較ページ (実測した zsh の画面) で決めた (refine-prompt-transient)。
  #   入力中: 1 行目に starship の状態行、2 行目に zsh の記号 %# だけ
  #   実行後: 状態行を消し、入力行を zsh の既定 "%n@%m %1~ %# コマンド" に置き換える
  #   失敗時: 実行結果の直後に "exit N" (パイプなら "exit 1|0") を 1 行残す
  # コマンドと実行結果を範囲選択してコピーしたとき、プロンプトの装飾が混ざらないようにするため。
  # 置き換えは上の programs.zsh.initContent (mkOrder 1400) が行う。
  programs.starship = {
    enable = true;
    settings = {
      # 状態行 1 行だけを出す。$character と改行は入れない — 記号は zsh の %# で描く。
      # starship の character には root を判定する機能がなく、所有者の指定は zsh 既定の
      # %# (通常 %、root なら #) だから (refine-prompt-transient)。
      #
      # format を明示すると、ここに書いたモジュールしか出ない。所有者が「不要」とした
      # 終了ステータスの数字・かかった時間・direnv・Kubernetes / Docker context・時刻・
      # バッテリー・言語やパッケージの版・gcloud (メールアドレスが出る) は、個別に
      # disabled を書かなくても表示されない。
      format = "$username$hostname$directory$git_branch$nix_shell$fill$git_state$git_status$jobs";

      # 左: ユーザー名とホスト名は starship の既定どおり SSH のときだけ出る。
      username.format = "[$user]($style) ";
      hostname = {
        ssh_symbol = "󰌘 ";
        format = "[$ssh_symbol$hostname]($style) ";
        style = "yellow";
      };
      directory = {
        style = "bold cyan";
        format = "[$path]($style)[$read_only]($read_only_style) ";
      };
      git_branch = {
        symbol = " ";
        format = "[$symbol$branch]($style) ";
        style = "purple";
      };
      nix_shell = {
        symbol = " ";
        format = "[$symbol]($style)";
        style = "blue";
      };

      # 右: $fill で状態行の右端に寄せる。right_format (zsh の RPROMPT) は入力行の右に
      # 出るため使わない。
      fill.symbol = " ";
      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        style = "red";
        # 既定の [!+?] は種類しか分からない。件数も出す。
        modified = "!\${count} ";
        staged = "+\${count} ";
        untracked = "?\${count} ";
        ahead = "⇡\${count} ";
        behind = "⇣\${count} ";
      };
    };

    # プリセット (tokyo-night / pastel-powerline 等) は採らない。
    #   - Ghostty が background-opacity = 0.8 + blur なので、背景色をべた塗り
    #     する powerline 系は透過の上で帯だけ浮く。
    #   - 画面上の主な視覚情報は delta の色付き差分であり、そちらと競合させない。
  };

  # (5) エージェントを並べて動かす

  # Claude Code / Codex を並列で動かすとき、入力待ちで止まっているセッションを
  # tmux のペインを巡回して探していた。herdr はペインごとにエージェントの状態
  # (working / blocked / done) を一覧する (add-herdr)。
  #
  # **エージェント作業専用で、tmux は置き換えない。入れ子にもしない** — Ghostty の
  # ウィンドウ / タブ単位で使い分ける。既定の prefix が同じ ctrl+b で、ssh 越しの
  # 環境を読み直す仕組み (tmux.nix の preexec) も herdr のペインには無いため
  # (terminal-tooling)。
  #
  # 接続元の Mac の herdr から、接続先の Mac の herdr に接続して使う (herdr-remote-machines)。
  # herdr のサーバーは起動時の SSH_AUTH_SOCK を持ち続け、接続し直しても更新しない。ssh の
  # 転送ソケットは接続ごとに作り直されるので、そのままでは接続し直した後の署名・push の
  # 承認が無人の接続先に出る。そこで herdr のペイン (HERDR_PANE_ID がある。herdr の
  # 公式ドキュメントに載っている変数) では、SSH_AUTH_SOCK を固定パス
  # ~/.ssh/agent-forward.sock にする (上の initContent)。先はログインのたびに ssh/rc が
  # 張り替える。ペインで起動した Claude Code もこの値を引き継ぐ。
  # 判定の条件は ssh.nix の 1Password の Match と git.nix の署名ラッパーにある。
  # 既知の制約: 接続元からの接続が残ったまま接続先の Mac の前で herdr のペインを使うと、
  # 承認は接続元に出る。接続先の前で使う前に、接続元の herdr を終了する (README)。
  #
  # 設定は宣言から生成する。`add-herdr` では「herdr が config.toml に自分で
  # 書き込むので settings は空にし、out-of-store symlink で置く」と決めたが、
  # `retire-out-of-store-symlinks` でそれを逆転させた。~/.config/herdr/config.toml は
  # store への読み取り専用コピーになる。
  #
  # **herdr の設定画面 (prefix+s) での変更は保存されない。** 書き込みは失敗し、
  # 次回の起動で消える。恒久的に変えるときはここを直して switch する。
  # 書くのは既定から変えたいものだけ。`herdr --default-config` の雛形を丸ごと
  # 写すと、herdr の更新で既定が変わっても古い値に固定される。
  programs.herdr = {
    enable = true;
    settings = {
      # 初回の onboarding を飛ばす。書いておかないと、herdr が onboarding の後に
      # 自分で書き足そうとする (読み取り専用なので、毎回 onboarding が出る)。
      onboarding = false;

      # Ghostty のテーマ (TokyoNight。modules/common/ghostty.nix) にそろえる。
      # 組み込みのテーマ名は `herdr --default-config` の [theme] に一覧がある。
      theme.name = "tokyo-night";
    };
  };
}
