{ username, ... }:
{
  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # home-manager の状態バージョン (初回導入時の値で固定し、以後変更しない)。
  home.stateVersion = "25.05";

  # home-manager 自身を home-manager で管理する。
  programs.home-manager.enable = true;
}
