{ pkgs, ... }:
{
  # CLI ツールを Nix ネイティブで宣言的に管理。
  # git / tmux / 端末ツール (jq / ripgrep / fd 等) / neovim は programs.* の
  # native モジュールへ移したため除外 (terminal.nix / neovim.nix)。
  # ここに残すのは native モジュールを持たないものだけ。
  #
  # **どの環境でも使うものだけを置く** (split-public-core)。ここに置いたものは
  # core を使うすべての環境に入り、利用側では外せない。特定の環境でだけ使う
  # ツールは、利用側が home.packages に足す。
  home.packages = with pkgs; [
    nodejs
    gh
    ghq
    uv
  ];
}
