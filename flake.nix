{
  description = "NixOS configuration for Hakula's machines";

  # ============================================================================
  # Inputs
  # ============================================================================
  inputs = {
    # Nixpkgs - NixOS 25.11 stable release
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    # Nixpkgs unstable - for bleeding edge packages
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

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
      nixpkgs-unstable,
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
        (final: prev: {
          unstable = import nixpkgs-unstable {
            localSystem = final.stdenv.hostPlatform.system;
            config.allowUnfree = true;
          };
          agenix = agenix.packages.${final.stdenv.hostPlatform.system}.default;
          cloudreve = final.callPackage ./packages/cloudreve { };
        })
      ];

      pkgsFor =
        system:
        import nixpkgs {
          inherit overlays;
          localSystem = system;
          config.allowUnfree = true;
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

      mkServer =
        {
          hostName,
          configPath,
        }:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs hostName;
          };
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
                extraSpecialArgs = {
                  inherit inputs;
                  isNixOS = true;
                  isDesktop = false;
                };
              };
            }
            configPath
          ];
        };
    in
    {
      # ========================================================================
      # NixOS Configurations (Linux servers)
      # ========================================================================
      nixosConfigurations = {
        # ----------------------------------------------------------------------
        # US-1 (CloudCone SC2)
        # ----------------------------------------------------------------------
        us-1 = mkServer {
          hostName = "us-1";
          configPath = ./hosts/us-1;
        };

        # ----------------------------------------------------------------------
        # US-2 (CloudCone VPS)
        # ----------------------------------------------------------------------
        us-2 = mkServer {
          hostName = "us-2";
          configPath = ./hosts/us-2;
        };

        # ----------------------------------------------------------------------
        # US-3 (CloudCone SC2)
        # ----------------------------------------------------------------------
        us-3 = mkServer {
          hostName = "us-3";
          configPath = ./hosts/us-3;
        };

        # ----------------------------------------------------------------------
        # SG-1 (Tencent Lighthouse)
        # ----------------------------------------------------------------------
        sg-1 = mkServer {
          hostName = "sg-1";
          configPath = ./hosts/sg-1;
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
            agenix.darwinModules.default
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.hakula = import ./home/hakula.nix;
                backupFileExtension = "bak";
                extraSpecialArgs = {
                  inherit inputs;
                  isNixOS = false;
                  isDesktop = true;
                };
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
          extraSpecialArgs = {
            inherit inputs;
            isNixOS = false;
            isDesktop = false;
          };
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
