{
  description = "NixOS configuration for Hakula's machines";

  # ============================================================================
  # Inputs
  # ============================================================================
  inputs = {
    # Nixpkgs - NixOS 25.05 stable release
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Declarative disk partitioning (Linux only)
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # User environment management
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # macOS system configuration
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets management
    agenix = {
      url = "github:ryantm/agenix";
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
      nix-darwin,
      agenix,
      ...
    }@inputs:
    {
      # ========================================================================
      # NixOS Configurations (Linux servers)
      # ========================================================================
      nixosConfigurations = {
        # ----------------------------------------------------------------------
        # CloudCone SC2 (Scalable Cloud Compute)
        # ----------------------------------------------------------------------
        cloudcone-sc2 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            agenix.nixosModules.default
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.hakula = import ./home/hakula.nix;
                backupFileExtension = "bak";
              };
            }
            ./hosts/cloudcone-sc2
          ];
        };
      };

      # ========================================================================
      # Darwin Configurations (macOS)
      # ========================================================================
      darwinConfigurations = {
        # ----------------------------------------------------------------------
        # Hakula's MacBook Pro
        # ----------------------------------------------------------------------
        hakula-macbook = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = { inherit inputs; };
          modules = [
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.hakula = import ./home/hakula.nix;
                backupFileExtension = "bak";
              };
            }
            ./hosts/hakula-macbook
          ];
        };
      };
    };
}
