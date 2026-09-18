# option を作る根拠は次のどちらか。それ以外は option にしない。
#
#   1. ホスト側が値を与える必要がある
#   2. 既定値を**ホスト依存の情報から導出する**必要がある
#
# 現在の option:
#   onePassword.enable → 2 (hostPlatform から導出)
#   git.signingKey     → 1 (利用側が与える。core は値を持たない。split-public-core)
#
# かつてあった repoDir (out-of-store symlink の参照先) と internal.guardedDirs
# (その symlink を守る防御の対象一覧) は、out-of-store symlink の撤去とともに
# 無くなった (retire-out-of-store-symlinks)。
#
# 意図的に option にしていないもの:
#   git identity、ユーザー名、ssh の接続先 — core のモジュールが**読まない**値である。
#   利用側が programs.git.settings.user.* や programs.ssh.settings.<host> に直接書けば、
#   モジュールシステムが core の宣言とマージする。option にしても指し先が増える
#   だけで何も表現しない。
{ lib, pkgs, ... }:
{
  options.dotfiles = {
    onePassword.enable = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.hostPlatform.isDarwin;
      description = ''
        このホストで 1Password を ssh 認証と git 署名に使うか。
        true のとき op-ssh-sign による署名設定と 1Password の SSH agent を
        指す ssh 設定を配置する。

        **利用側との約束 (split-public-core):** 1Password のアプリ
        (/Applications/1Password.app) と、その SSH agent を有効にしておく。
        アプリは core の Homebrew のリストが宣言しているが、それが効くのは利用側が
        homebrew.enable = true にしたときだけ。

        **既定値を hostPlatform から導出している**のがこの option の存在理由。
        macOS のアプリケーションバンドル内の絶対パスと Group Containers の
        ソケットパスを modules/common/ の無条件な事実にしないためで、
        1Password を動かさないホストでは false にして設定自体を出力しない。
      '';
    };

    git.signingKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "ssh-ed25519 AAAA... comment";
      description = ''
        git のコミット署名に使う公開鍵 (OpenSSH の公開鍵の 1 行)。

        **利用側が値を与える**のがこの option の存在理由 (split-public-core)。
        鍵は環境ごとに違い、core は値を持たない。git.nix はこの値から
        user.signingkey を組み立て、commit.gpgsign と組にしている。

        null のとき署名の設定を出力しない。鍵を与えない利用側で
        commit.gpgsign だけが入ると、コミットが失敗するため。
        署名するのは onePassword.enable も true のときだけ。
      '';
    };
  };
}
