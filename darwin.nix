{ username, ... }:
{
  # 対象アーキテクチャ (Apple Silicon)。
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Determinate Nix が Nix 本体/設定を管理するため、nix-darwin 側の Nix 管理は
  # 無効化して競合 (activation abort) を避ける。カスタム Nix 設定が必要になったら
  # /etc/nix/nix.custom.conf 側で行う (design Decision 4)。
  nix.enable = false;

  # user 単位のオプション (home-manager / 将来の homebrew 等) が参照する主ユーザー。
  system.primaryUser = username;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # GUI アプリ (cask) と Mac App Store アプリ (mas) は Nix ネイティブでは扱えないため、
  # nix-darwin の homebrew モジュールで宣言的に管理する (Phase 3)。実体は既存の
  # Homebrew (/opt/homebrew) が brew bundle で導入する。
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false; # switch のたびに brew update しない (高速・予測可能)
      upgrade = false; # 既存パッケージを勝手に upgrade しない
      # Phase 3 は非破壊 ("none": 未列挙パッケージを一切削除しない)。
      # nix へ移行した 9 formula の brew 重複掃除は、内容確認のうえ後で
      # "uninstall" へ厳格化する (design Risks / tasks 3.5)。
      cleanup = "none";
    };

    # nixpkgs 未提供 or brew 必須の formula のみ残す。
    #   mas      : masApps 導入に必要
    #   chezmoi  : Phase 4 の一致確認に使用 (撤去は Phase 5)
    #   appium/periphery : nixpkgs 未提供 (task 0.3 で確認済み)
    brews = [
      "mas"
      "chezmoi"
      "appium"
      "periphery"
    ];

    casks = [
      "1password"
      "1password-cli"
      "adobe-creative-cloud"
      "brave-browser"
      "claude"
      # "claude-code" は declarative 管理から除外。Homebrew 管理下だと自動アップデートが
      # 無効化されるため、自動更新される native インストーラ版で管理する。
      "discord"
      "docker-desktop"
      "firefox"
      "font-sauce-code-pro-nerd-font"
      "font-source-han-code-jp"
      "gcloud-cli"
      "ghostty"
      "google-chrome"
      "obsidian"
      "postman"
      "pycharm"
      "tailscale-app"
      "visual-studio-code"
      "vlc"
      "webstorm"
    ];

    masApps = {
      "Keynote" = 409183694;
      "Kindle" = 302584613;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "Spark" = 1176895641;
      "Xcode" = 497799835;
    };
  };

  # nix-darwin の状態バージョン (初回導入時の値で固定し、以後変更しない)。
  system.stateVersion = 6;
}
