# macOS の共通構成のうち、どの環境でも使うもの。ユーザー名、stateVersion、
# Homebrew の方針、authorized keys のような環境固有の値は利用側が与える
# (split-public-core)。
#
# **home-manager の darwin モジュールを利用側が読み込んでいることを前提にする。**
# 下で home-manager.* を設定するため。
{ ... }:
{
  imports = [
    ./homebrew.nix
  ];

  # Determinate Nix が Nix 本体/設定を管理するため、nix-darwin 側の Nix 管理は
  # 無効化して競合 (activation abort) を避ける。カスタム Nix 設定が必要になったら
  # /etc/nix/nix.custom.conf 側で行う。
  nix.enable = false;

  # sshd は公開鍵認証だけを受け付ける (harden-remote-login)。
  # リモートログインは接続中のすべてのネットワークで 22 番を開けるため、公衆
  # Wi-Fi 上に持ち出した Mac にも第三者が到達できる。
  #
  # KbdInteractiveAuthentication も塞ぐのは、100-macos.conf が UsePAM yes に
  # しており、PAM 経由のパスワード入力がそちらで提示されるため。
  # sshd は同じキーワードの最初の値を採る。100-macos.conf はこれらを設定して
  # いないので、ファイル名順で後ろの 100-nix-darwin.conf の値が効く。macOS の
  # 更新後は `sudo sshd -T` で実効値を確認すること。
  #
  # services.openssh.enable は宣言しない (null)。true / false を与えると switch の
  # たびにリモートログインのオン / オフが巻き戻り、GUI で切り替える運用ができない。
  #
  # 応答しないクライアントの接続は約 1 分 (15 秒 × 4 回) で切る (herdr-remote-machines)。
  # 既定の ClientAliveInterval は 0 で、頼れるのは TCPKeepAlive (macOS では検出に 2 時間ほど)
  # だけになる。スリープした Mac からの接続は TCP の切断が届かず、転送された agent の
  # ソケットが残り続ける。ssh/rc は先が生きているリンクを張り替えないので、次の接続でも
  # 直らず、herdr のペインの署名が応答しない agent に向かって止まる。間隔は herdr が
  # 接続元で使う生存確認 (ServerAliveInterval 15 / ServerAliveCountMax 4) にそろえる。
  # 起きている接続は応答するので、長い処理や放置した対話シェルは切れない。
  services.openssh.extraConfig = ''
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    AuthenticationMethods publickey
    ClientAliveInterval 15
    ClientAliveCountMax 4
  '';

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # 既存の素ファイルと衝突した場合は .hm-bak へ退避してから HM のファイルを
    # 配置する (消失防止の安全網)。**退避されたファイルは、現行との差分を取って
    # から消す** — そのホストでしか有効化していなかった設定が入っていることが
    # ある (multi-host-dotfiles)。
    backupFileExtension = "hm-bak";
  };
}
