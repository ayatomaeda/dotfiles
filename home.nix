{ pkgs, username, ... }:
{
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # home-manager の状態バージョン (初回導入時の値で固定し、以後変更しない)。
  home.stateVersion = "25.05";

  # CLI ツールを Nix ネイティブで宣言的に管理 (Phase 2)。
  # nixpkgs 未提供の appium / periphery は Phase 3 で homebrew.brews に残す。
  # git / tmux は Phase 4 で programs.* の native モジュールへ移す予定。
  home.packages = with pkgs; [
    git
    tmux
    nodejs
    ffmpeg
    gh
    ghq
    uv
    yt-dlp
    swiftlint
  ];

  # home-manager 自身を home-manager で管理する。
  programs.home-manager.enable = true;
}
