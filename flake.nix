{
  description = "NixOS configuration for hakula.xyz";

  # ============================================================================
  # Inputs
  # ============================================================================
  inputs = {
    # NixOS 25.05 stable release
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # User environment management
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ============================================================================
  # Outputs
  # ============================================================================
  outputs =
    {
      self,
      nixpkgs,
      disko,
      home-manager,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        # ------------------------------------------------------------------------
        # CloudCone SC2 (Scalable Cloud Compute)
        # ------------------------------------------------------------------------
        cloudcone-sc2 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.hakula = import ./home/hakula.nix;
              };
            }
            ./hosts/cloudcone-sc2
          ];
        };
      };
    };
}
