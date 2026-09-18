{ ... }:
{
  # EDITOR の実体。これまで EDITOR=vim は macOS 同梱の /usr/bin/vim (9.1) を
  # 指しており、flake の pin の外にあった。
  #
  # プラグイン / LSP の設定は持たない (modernize-terminal-env の Non-Goal)。
  # エディタとしては VS Code / JetBrains を併用しており、端末のエディタに
  # 求めているのは「修正できること」まで。
  programs.neovim = {
    enable = true;
    # home.sessionVariables に EDITOR と VISUAL を設定する。
    # zsh.nix の initContent へ手書きで export しない。
    defaultEditor = true;

    # Ruby / Python3 の remote plugin provider を無効にする。
    # home.stateVersion が "25.05" のため既定は legacy の true で、有効のままだと
    # プラグインを 1 つも持たないのに閉包へ ruby と python3 一式が入る
    # (実測: 876.0 MiB)。プラグインは持たない方針なので provider は要らない。
    # 明示しておくと switch のたびに出る「既定値が変わった」警告も消える。
    withRuby = false;
    withPython3 = false;
  };
}
