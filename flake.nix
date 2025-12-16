{
  description = "NixOS configuration for Hakula's machines";

  # ============================================================================
  # Inputs
  # ============================================================================
  inputs = {
    # Nixpkgs - NixOS 25.11 stable release
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # macOS system configuration
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # User environment management
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative disk partitioning (Linux only)
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets management
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pre-commit hooks
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
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
      git-hooks-nix,
      ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      overlays = [
        (final: _prev: {
          agenix = agenix.packages.${final.stdenv.hostPlatform.system}.default;
        })
      ];

      pkgsFor =
        system:
        import nixpkgs {
          inherit overlays;
          localSystem = system;
        };

      preCommitCheckFor =
        system:
        git-hooks-nix.lib.${system}.run {
          src = ./.;
          hooks = {
            check-added-large-files.enable = true;
            check-yaml.enable = true;
            end-of-file-fixer.enable = true;
            trim-trailing-whitespace.enable = true;
            nixfmt-rfc-style.enable = true;
          };
        };
    in
    {
      # ========================================================================
      # NixOS Configurations (Linux servers)
      # ========================================================================
      nixosConfigurations = {
        # ----------------------------------------------------------------------
        # CloudCone SC2 (Scalable Cloud Compute)
        # ----------------------------------------------------------------------
        cloudcone-sc2 = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            {
              nixpkgs.hostPlatform = "x86_64-linux";
              nixpkgs.overlays = overlays;
            }
            agenix.nixosModules.default
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.hakula = import ./home/hakula.nix;
                backupFileExtension = "bak";
                extraSpecialArgs.isNixOS = true;
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
          modules = [
            {
              nixpkgs.hostPlatform = "aarch64-darwin";
              nixpkgs.overlays = overlays;
            }
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

      # ========================================================================
      # Home Manager Configurations (standalone, for non-NixOS Linux)
      # ========================================================================
      homeConfigurations = {
        # ----------------------------------------------------------------------
        # Generic Linux (e.g., Ubuntu WSL)
        # ----------------------------------------------------------------------
        hakula-linux = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor "x86_64-linux";
          modules = [
            ./home/hakula.nix
          ];
          extraSpecialArgs.isNixOS = false;
        };
      };

      # ========================================================================
      # Pre-commit Hooks (git-hooks.nix)
      # ========================================================================
      checks = forAllSystems (system: {
        pre-commit = preCommitCheckFor system;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          preCommitCheck = preCommitCheckFor system;
        in
        {
          default = pkgs.mkShell {
            buildInputs = preCommitCheck.enabledPackages;
            shellHook = preCommitCheck.shellHook;
          };
        }
      );

      # ========================================================================
      # Formatter (nix fmt)
      # ========================================================================
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-rfc-style);
    };
}
