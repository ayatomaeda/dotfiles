{ config, lib, pkgs, ... }:
{
  # zsh を native モジュール化。既存 .zshrc の挙動を移植。
  programs.zsh = {
    enable = true;

    history = {
      path = "${config.home.homeDirectory}/.zsh_history";
      size = 1000000;
      save = 1000000;
      extended = true; # extended_history
      share = true; # share_history
      # 旧 .zshrc は重複・先頭スペースのコマンドも記録していたため、HM 既定 (true) を
      # 無効化して従来どおり全記録にする。
      ignoreDups = false;
      ignoreSpace = false;
    };

    # 補完の dump を zsh の版ごとのファイルにする (single-zsh-compinit)。compinit は dump の
    # 1 行目のファイルの個数と zsh の版が今のシェルと違えば作り直す。対話シェルは macOS の
    # /bin/zsh (ログインシェル) で、PATH の zsh は Nix の zsh なので、1 つの dump を使うと、
    # 片方を起動するたびにもう片方の dump が捨てられる。zsh を 1 つにそろえる宣言は無い
    # (管理者ユーザーのログインシェルは nix-darwin が宣言しない)。置き場所は compinit の既定に
    # 版を足したもの。補完の初期化はここの 1 回だけで、/etc/zshrc の compinit は darwin の
    # モジュールが止める。
    completionInit = ''autoload -U compinit && compinit -d "''${ZDOTDIR:-$HOME}/.zcompdump-$ZSH_VERSION"'';

    shellAliases = {
      ls = "ls -GF";
      ll = "ls -lGF";
      la = "ls -alGF";
      history = ''history -t "%F %T"'';
    };

    # プラットフォーム固有の記述は評価時に分岐してモジュール内部へ閉じる
    # (multi-host-dotfiles)。旧実装はシェルの実行時分岐 (OSTYPE の判定) を使って
    # いたが、それは撤去した ssh() 関数が .zshrc をリモートへ送っていたための
    # 仕掛けだった。送らなくなったので、そのホストに不要な記述を生成物へ含めない。
    initContent = lib.mkMerge [
      ''
        export LANG=ja_JP.UTF-8
        # EDITOR / VISUAL は programs.neovim.defaultEditor が
        # home.sessionVariables 経由で設定する (neovim.nix)。ここには書かない。
        # プロンプトは programs.starship が生成する (terminal.nix)。
        # PROMPT= をここに残すと生成物の後勝ちに依存する状態になるため置かない。

        autoload -Uz colors && colors

        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
        zstyle ':completion:*:default' menu select=1
        zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/X11R6/bin

        setopt hist_verify
        setopt hist_reduce_blanks
        setopt hist_no_store
        setopt hist_expand

        export LSCOLORS=cxfxcxdxbxegedabagacad
      ''

      # 補完の初期化 (home-manager の compinit、mkOrder 570) より前、home-manager の fpath の
      # 組み立て (typeset -U を含む、mkOrder 510-540) より後に置く (single-zsh-compinit)。
      # brew shellenv は fpath に Homebrew の補完を足す。compinit の後に置くと、端末のアプリが
      # 起動したシェルの dump には入らず、そのシェルから起動したシェル (export された FPATH で
      # 受け継ぐ) の dump には入るので、個数が違って dump を作り直し合う (実測)。typeset -U の後に
      # 置けば、受け継いだ重複も除かれる。FPATH の export は Homebrew が子のシェルに補完を
      # 届けるために足したもので、外さない。PATH の並べ直しも一緒に動くが、順序 1000 までの
      # 初期化は絶対パスで呼ばれるので PATH に依らない。
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.mkOrder 550 ''
        # Homebrew (cask/mas 用 formula の CLI を PATH に載せる)
        eval "$(/opt/homebrew/bin/brew shellenv)"
        # ~/.local/bin と Nix プロファイルを Homebrew より優先させる。
        # brew shellenv が /opt/homebrew/bin を先頭に積むため、明示的に戻している。
        # Nix を情報源とし Homebrew を裏方に留める方針上、同名コマンドは常に Nix 側を
        # 使う。cask が入れた CLI が Nix のツールを隠さないための予防。
        export PATH="$HOME/.local/bin:/etc/profiles/per-user/$USER/bin:$PATH"
      ''))

      (lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) ''
        export PATH="$HOME/.local/bin:$PATH"
      '')
    ];
  };
}
