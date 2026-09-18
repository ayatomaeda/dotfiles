{
  description = "macOS の共通構成 (nix-darwin + home-manager のモジュール)";

  # 利用側の flake が input として取り込み、ホストの構成を組み立てる。
  # このリポジトリ自身は実在のホストを宣言しない (split-public-core)。
  #
  # 下の input は、評価用の例の構成 (darwinConfigurations.example) のためだけにある。
  # 利用側は follows で自分の nixpkgs / nix-darwin / home-manager にそろえるので、
  # モジュールは利用側の pkgs と lib で評価される。このリポジトリの flake.lock は
  # 利用側の構成に影響しない。
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nix-darwin,
      home-manager,
      ...
    }:
    {
      # nix-darwin のモジュール。home-manager の darwin モジュールは読み込まない
      # (利用側が読み込む)。home-manager.* を設定するので、それが前提になる。
      darwinModules.default = ./modules/darwin;

      # home-manager のモジュール。
      homeModules.default = ./modules/common;

      # **評価用の例の構成。実在のホストではない。** CI がこれを評価して、モジュールが
      # 利用側なしでも壊れていないことを確かめる。利用側が与える値はここでは架空のもの
      # を使う。利用側の書き方の見本も兼ねる (README の「使い方」)。
      darwinConfigurations.example = nix-darwin.lib.darwinSystem {
        modules = [
          home-manager.darwinModules.home-manager
          self.darwinModules.default
          {
            nixpkgs.hostPlatform = "aarch64-darwin";
            system.primaryUser = "example";
            users.users.example.home = "/Users/example";
            system.stateVersion = 6;

            home-manager.users.example = {
              imports = [ self.homeModules.default ];
              home.stateVersion = "25.05";
              programs.git.settings.user = {
                name = "Example";
                email = "example@example.com";
              };
            };
          }
        ];
      };
    };
}
