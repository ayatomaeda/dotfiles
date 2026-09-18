# Claude Code のユーザー設定 (~/.claude/settings.json とステータスライン)。
#
# 以前は claude/settings.json への out-of-store symlink で置いていた。Claude Code が
# 自分でも書き込むファイルだからだが、所有者の判断で宣言を唯一の情報源にした
# (retire-out-of-store-symlinks)。
#
# **アプリ側の変更は保存されない。** モジュールは settings.json をパーミッション 444 で
# 置くので、`/config` での変更・権限の「常に許可」・プラグインの切り替えは
# **エラーにならずそのセッション限り**になり、次の起動で消える (公式ドキュメント)。
# ユーザー単位の settings.local.json は存在しない。恒久的に変えるときは下の settings を
# 直して switch する。
{ lib, pkgs, ... }:
let
  # ステータスラインのスクリプト。実体は claude/statusline-command.sh に置いたまま
  # store へ入れる — 100 行の bash を Nix の文字列に埋めると ''${...} の
  # エスケープだらけになり、shellcheck も効かなくなるため。
  #
  # writeShellScript は自分で #!${pkgs.runtimeShell} を付けるので、ファイル側の
  # 1 行目 (#!/bin/bash) は落として渡す。**shell は bash でなければならない** —
  # スクリプトは (( )) の算術と ${BRANCH:0:20} の部分文字列展開を使う。
  # 実行可能属性は writeShellScript が付ける。
  statuslineSource = builtins.readFile ../../claude/statusline-command.sh;
  statusline = pkgs.writeShellScript "claude-statusline" (
    lib.removePrefix "#!/bin/bash\n" statuslineSource
  );
in
{
  assertions = [
    {
      assertion = lib.hasPrefix "#!/bin/bash\n" statuslineSource;
      message = ''
        modules/common/claude-code.nix: claude/statusline-command.sh の 1 行目が
        "#!/bin/bash" ではありません。

        writeShellScript は自分で shebang を付けるため、ファイル側の shebang を
        取り除いて渡しています。1 行目が変わると、元の shebang が本体の 1 行目
        として残り、コメント扱いで黙って動き続けます。
      '';
    }
  ];

  programs.claude-code = {
    enable = true;

    # **パッケージは入れない。** Claude Code は自動更新される公式インストーラ版で
    # 管理している (modules/darwin/homebrew.nix のコメントと同じ理由)。
    package = null;

    # 移行前の claude/settings.json と同じ値 (statusLine.command だけは store の
    # 絶対パスに変えた)。モジュールは $schema を必ず足す。
    settings = {
      statusLine = {
        type = "command";
        # store の絶対パス。~/.claude/statusline-command.sh を経由しないので、
        # 設定と実体が別々に入れ替わる状態を作らない。
        command = "${statusline}";
      };

      enabledPlugins = {
        "frontend-design@claude-plugins-official" = true;
        "superpowers@claude-plugins-official" = true;
        "vercel@claude-plugins-official" = true;
      };

      # **モジュールの marketplaces option は使わない。** それを使うと
      # ~/.claude/plugins/known_marketplaces.json も store の読み取り専用コピーに
      # なるが、このファイルは Claude Code 自身が書き換える (実測: プラグインの
      # 導入で更新される)。settings.json の中の extraKnownMarketplaces として
      # 書けば、生成されるファイルは settings.json だけで済む。
      extraKnownMarketplaces = {
        chrome-devtools-plugins.source = {
          source = "github";
          repo = "ChromeDevTools/chrome-devtools-mcp";
        };
      };

      agentPushNotifEnabled = true;
    };
  };
}
