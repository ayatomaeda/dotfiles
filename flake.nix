{
  description = "ayatomaeda's macOS configuration (nix-darwin + home-manager)";

  inputs = {
    # 再現性は flake.lock がピン留めするため、チャンネルは unstable を採用
    # (darwin のパッケージ網羅性・鮮度が良い)。
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
      nixpkgs,
      nix-darwin,
      home-manager,
    }:
    let
      hostname = "KeisukenoMac-Studio";
      username = "keisuke";
    in
    {
      darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit username; };
        modules = [
          ./darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = import ./home.nix;
            home-manager.extraSpecialArgs = { inherit username; };
          }
        ];
      };
    };
}
