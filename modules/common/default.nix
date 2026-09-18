# OS 非依存のユーザー設定。プラットフォーム固有の記述を持ち込まず、
# モジュール内部で評価時に分岐させる (multi-host-dotfiles)。
#
# 純粋な home-manager モジュールとして書いてあるので standalone home-manager
# からも import できるが、**その使い方は動作確認していない**。形を保っているだけ。
{ ... }:
{
  imports = [
    ./options.nix
    ./packages.nix
    ./zsh.nix
    ./git.nix
    ./tmux.nix
    ./terminal.nix
    ./ghostty.nix
    ./claude-code.nix
    ./ssh.nix
    ./neovim.nix
  ];

  # home-manager 自身を home-manager で管理する。
  programs.home-manager.enable = true;
}
