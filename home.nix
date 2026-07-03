{ config, pkgs, username, ... }:
let
  # out-of-store symlink の参照先 (リポジトリの実体パス)。
  # 生ファイルを編集すると rebuild なしで即反映される。
  repoDir = "/Users/${username}/git/github.com/ayatomaeda/dotfiles";
in
{
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # home-manager の状態バージョン (初回導入時の値で固定し、以後変更しない)。
  home.stateVersion = "25.05";

  # CLI ツールを Nix ネイティブで宣言的に管理 (Phase 2)。
  # git / tmux は Phase 4 で programs.* の native モジュールへ移したため除外。
  # nixpkgs 未提供の appium / periphery は homebrew.brews (darwin.nix)。
  home.packages = with pkgs; [
    nodejs
    ffmpeg
    gh
    ghq
    uv
    yt-dlp
    swiftlint
  ];

  # zsh を native モジュール化 (Phase 4)。既存 .zshrc の挙動を移植。
  programs.zsh = {
    enable = true;

    history = {
      path = "${config.home.homeDirectory}/.zsh_history";
      size = 1000000;
      save = 1000000;
      extended = true; # extended_history
      share = true; # share_history
    };

    shellAliases = {
      ls = "ls -GF";
      ll = "ls -lGF";
      la = "ls -alGF";
      history = ''history -t "%F %T"'';
    };

    initContent = ''
      export LANG=ja_JP.UTF-8
      export EDITOR=vim
      PROMPT="%n@%M %1~ %# "

      autoload -Uz colors && colors

      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
      zstyle ':completion:*:default' menu select=1
      zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/X11R6/bin

      setopt hist_verify
      setopt hist_reduce_blanks
      setopt hist_no_store
      setopt hist_expand

      export LSCOLORS=cxfxcxdxbxegedabagacad

      # ssh コマンドのオーバーライド（接続前にリモートへ .zshrc を送る）
      function ssh() {
          local user_host=$1
          local local_zshrc="$HOME/.zshrc"
          if [[ -f $local_zshrc ]]; then
              echo "Uploading .zshrc to $user_host..."
              scp $local_zshrc "$user_host:~" || {
                  echo "Failed to upload .zshrc. Continuing with SSH."
              }
          else
              echo "No .zshrc file found at $local_zshrc. Continuing with SSH."
          fi
          command ssh "$@"
      }

      # Homebrew (cask/mas 用 formula の CLI を PATH に載せる)
      eval "$(/opt/homebrew/bin/brew shellenv)"

      # ~/.local/bin と Nix プロファイルを Homebrew より優先させる。
      # (appium の依存で入る brew node より nix の node を優先させるため)
      export PATH="$HOME/.local/bin:/etc/profiles/per-user/$USER/bin:$PATH"
    '';
  };

  # git を native モジュール化 (Phase 4)。1Password 署名 (op-ssh-sign) を保持。
  programs.git = {
    enable = true;
    settings = {
      user.name = "ayatomaeda";
      user.email = "ayatomaeda@users.noreply.github.com";
      user.signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICfj37x/HmqRIEoKxnk8f9j1UHmb37DgnYClUBZI1Q34";
      gpg.format = "ssh";
      gpg."ssh".program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      commit.gpgsign = true;
      init.defaultBranch = "main";
      ghq.root = "~/git";
    };
  };

  # tmux を native モジュール化 (Phase 4)。現状 dotfiles に tmux 設定は無いため最小。
  programs.tmux.enable = true;

  # アプリ固有形式 / 頻繁編集の生ファイルは out-of-store symlink (design Decision 5)。
  # リポジトリ実体へ直接リンクするため、編集後 rebuild なしで反映される。
  home.file.".config/ghostty/config".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/config/ghostty/config";
  home.file.".ssh/config".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/ssh/config";
  home.file.".ssh/config.d".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/ssh/config.d";
  home.file.".claude/statusline-command.sh".source =
    config.lib.file.mkOutOfStoreSymlink "${repoDir}/claude/statusline-command.sh";

  # home-manager 自身を home-manager で管理する。
  programs.home-manager.enable = true;
}
