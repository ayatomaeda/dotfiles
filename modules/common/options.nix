# option を作る根拠は次のどちらか。それ以外は option にしない。
#
#   1. ホスト側が値を与える必要がある
#   2. 既定値を**ホスト依存の情報から導出する**必要がある
#
# 現在の option:
#   onePassword.enable → 2 (hostPlatform から導出)
#   git.signingKeyName → 1 (利用側が与える。core は値を持たない。select-signing-key-by-name)
#
# かつてあった git.signingKey (公開鍵の文字列) は git.signingKeyName に置き換えた。
# 与えた構成は、移行先を示すメッセージで評価に失敗する (下の mkRemovedOptionModule)。
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
  # 意味が変わる (公開鍵 → 名前) ので mkRenamedOptionModule は使えない。
  # 併存させると公開鍵の写しを置く二重管理を選べてしまうので、残さない。
  imports = [
    (lib.mkRemovedOptionModule [ "dotfiles" "git" "signingKey" ] ''
      公開鍵の文字列を与える代わりに、1Password の項目名を
      dotfiles.git.signingKeyName = "<項目名>"; で与える。
      git は署名のたびに 1Password の SSH agent から、その名前の鍵を選ぶ。
    '')
  ];

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

    git.signingKeyName = lib.mkOption {
      type = lib.types.nullOr lib.types.nonEmptyStr;
      default = null;
      example = "Git signing key";
      description = ''
        git のコミット署名に使う鍵の、1Password の項目名。

        **利用側が値を与える**のがこの option の存在理由。鍵を指す名前は
        環境ごとに違い、core は値を持たない。公開鍵そのものは利用側に置かない。

        1Password の SSH agent は項目名を鍵のコメントとして返す。git は署名のたびに
        gpg.ssh.defaultKeyCommand で agent の鍵の一覧を取り、コメントがこの名前と
        完全に一致する鍵がちょうど 1 本のときだけ、それで署名する (git.nix)。
        一致しない・複数ある・agent に接続できないときは、署名せずに止まる。

        - null のとき署名の設定を出力しない。onePassword.enable が false のときも同じ。
        - 1Password で項目名を変えたら、この値も直す。直すまで署名は止まる。
        - user.signingkey を直接書かない (programs.git.settings.user.signingkey、
          programs.git.signing.key を含む)。git は user.signingkey があると
          defaultKeyCommand を使わなくなり、名前による選択が黙って外れる。
          署名の設定を出力する構成では、宣言すると評価に失敗する。
      '';
    };
  };
}
