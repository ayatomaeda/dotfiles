{ username, ... }:
{
  # 対象アーキテクチャ (Apple Silicon)。
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Determinate Nix が Nix 本体/設定を管理するため、nix-darwin 側の Nix 管理は
  # 無効化して競合 (activation abort) を避ける。カスタム Nix 設定が必要になったら
  # /etc/nix/nix.custom.conf 側で行う (design Decision 4)。
  nix.enable = false;

  # user 単位のオプション (home-manager / 将来の homebrew 等) が参照する主ユーザー。
  system.primaryUser = username;

  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # nix-darwin の状態バージョン (初回導入時の値で固定し、以後変更しない)。
  system.stateVersion = 6;
}
