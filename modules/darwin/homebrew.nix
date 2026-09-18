# どの環境でも使う GUI アプリ (cask)、Mac App Store アプリ (mas)、formula。
#
# **リストだけを宣言する** (split-public-core)。homebrew.enable と onActivation
# (更新や cleanup の方針) は利用側が決める。利用側が homebrew.enable を true に
# しなければ、ここのリストは何も導入しない。
#
# ここに置いたものは core を使うすべての環境に入り、利用側では外せない。
# 特定の環境でだけ使うアプリは、利用側が homebrew.casks / masApps に足す。
{ ... }:
{
  homebrew = {
    # Homebrew でしか導入できない formula。
    #   mas : masApps の導入に必要
    brews = [
      "mas"
    ];

    # ghostty と 2 つのフォントは modules/common/ghostty.nix が前提にしている
    # (設定だけを生成し、本体とフォントはここで入れる)。1password は署名と ssh の
    # agent (git.nix / ssh.nix) が前提にしている。
    casks = [
      "1password"
      "1password-cli"
      "claude"
      # "claude-code" は declarative 管理から除外。Homebrew 管理下だと自動アップデートが
      # 無効化されるため、自動更新される native インストーラ版で管理する。
      "firefox"
      "font-sauce-code-pro-nerd-font"
      "font-source-han-code-jp"
      "ghostty"
      "google-chrome"
      "obsidian"
      "visual-studio-code"
    ];

    masApps = {
      "Keynote" = 409183694;
      "Numbers" = 409203825;
      "Pages" = 409201541;
      "Xcode" = 497799835;
    };
  };
}
