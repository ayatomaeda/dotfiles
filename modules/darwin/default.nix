# macOS の共通構成のうち、どの環境でも使うもの。ユーザー名、stateVersion、
# Homebrew の方針、authorized keys のような環境固有の値は利用側が与える
# (split-public-core)。
#
# **home-manager の darwin モジュールを利用側が読み込んでいることを前提にする。**
# 下で home-manager.* を設定するため。
{ config, lib, ... }:
{
  imports = [
    ./homebrew.nix
  ];

  # Nix の設定 (/etc/nix/nix.conf、registry) と daemon は nix-darwin が管理する
  # (use-upstream-nix)。**その Mac の Nix は upstream の Nix であることを前提にする。**
  # Determinate Nix が残っていると、nix-darwin の検査で activation が止まる
  # (入れ替えの手順は、コミット ba5dfb1 の README にある)。
  #
  # flakes はここで有効にする。インストーラも nix.conf に書くが、nix-darwin が
  # nix.conf を置き換えるので、宣言が無いと switch の後に消える。
  #
  # channel は使わない。構成は flake だけで扱い、NIX_PATH の nixpkgs は
  # nix-darwin が利用側の flake.lock の nixpkgs に固定した registry で解決される。
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.channel.enable = false;

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

  # 補完の初期化 (compinit) は home-manager の ~/.zshrc の 1 回だけにする (single-zsh-compinit)。
  # nix-darwin は既定で全ユーザー向けの /etc/zshrc でも compinit を呼ぶ。2 回の compinit は
  # 別々の fpath (/etc/zshrc の時点では home-manager の typeset -U も Homebrew の補完もまだ無い) を
  # 数えるので、個数が食い違うと dump (~/.zcompdump*) を起動のたびに作り直し合う。
  # 残すのが home-manager 側なのは、fpath を組み立てた後、compdef を使う初期化 (fzf、zoxide) の前に
  # home-manager 自身が並べ、nix-darwin の無い環境でも同じ ~/.zshrc で動くため。
  # enable と enableCompletion は既定のまま (前者を切ると /etc/zshenv の Nix の環境ごと消え、
  # 後者を切ると nix-zsh-completions も消える)。bashcompinit は compinit より前でも警告を出さない。
  # 前提: home-manager を使わないアカウントの対話 zsh には、補完の初期化が無い。
  programs.zsh.enableGlobalCompInit = false;

  # 上で /etc/zshrc の compinit を止めたので、home-manager の zsh の補完が切られると、どこにも
  # compinit が無くなり、補完と compdef を使う初期化 (fzf、zoxide) が黙って失われる。
  # home-manager のユーザーについては評価で止める。home-manager を使わない macOS のアカウントは
  # 構成から見えないので、ここでは守れない (README の「利用側が与えるもの」)。
  assertions =
    let
      hmUsers = config.home-manager.users;
      lacking = lib.filterAttrs (_: u: !(u.programs.zsh.enable && u.programs.zsh.enableCompletion)) hmUsers;
    in
    [
      {
        assertion = hmUsers != { };
        message = ''
          dotfiles (single-zsh-compinit): home-manager.users が空。core は nix-darwin の
          /etc/zshrc の compinit を止め、補完の初期化を home-manager の ~/.zshrc に任せている。
          対話で使うユーザーを home-manager.users に宣言する。
        '';
      }
      {
        assertion = lacking == { };
        message = ''
          dotfiles (single-zsh-compinit): home-manager の programs.zsh.enable か enableCompletion が
          false のユーザーがいる (${lib.concatStringsSep ", " (lib.attrNames lacking)})。core は
          nix-darwin の /etc/zshrc の compinit を止めているので、このユーザーの対話 zsh には
          補完の初期化が無くなる。
        '';
      }
    ];

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
