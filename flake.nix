# ==================================================================================================
# NixOS Configuration Flake
# ==================================================================================================

{
  description = "NixOS configuration for Hakula's machines";

  # ------------------------------------------------------------------------------------------------
  # Inputs
  # ------------------------------------------------------------------------------------------------
  inputs = {
    # ----------------------------------------------------------------------------------------------
    # Nixpkgs
    # ----------------------------------------------------------------------------------------------
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # ----------------------------------------------------------------------------------------------
    # System frameworks
    # ----------------------------------------------------------------------------------------------
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    system-manager = {
      url = "github:numtide/system-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ----------------------------------------------------------------------------------------------
    # Deployment and secrets
    # ----------------------------------------------------------------------------------------------
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    colmena = {
      url = "github:nix-community/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.stable.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ----------------------------------------------------------------------------------------------
    # Development tools
    # ----------------------------------------------------------------------------------------------
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ----------------------------------------------------------------------------------------------
    # LLM agents
    # ----------------------------------------------------------------------------------------------
    llm-agents.url = "github:numtide/llm-agents.nix";

    # ----------------------------------------------------------------------------------------------
    # Hakula's flakes
    # ----------------------------------------------------------------------------------------------
    agents-nix = {
      url = "github:hakulab/agents.nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-unstable.follows = "nixpkgs-unstable";
        devkit.follows = "devkit";
        home-manager.follows = "home-manager";
        llm-agents.follows = "llm-agents";
      };
    };

    devkit = {
      url = "github:hakulab/devkit/v3";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-unstable.follows = "nixpkgs-unstable";
        git-hooks-nix.follows = "git-hooks-nix";
      };
    };

    flake-catalog.url = "github:hakulab/flake-catalog";
  };

  # ------------------------------------------------------------------------------------------------
  # Outputs
  # ------------------------------------------------------------------------------------------------
  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      # --------------------------------------------------------------------------------------------
      # Nixpkgs
      # --------------------------------------------------------------------------------------------
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      overlays = import ./lib/overlays.nix {
        inherit inputs;
      };

      pkgsFor =
        system:
        import nixpkgs {
          inherit overlays;
          localSystem = system;
          config.allowUnfree = true;
        };

      mkCachixPins =
        pkgs: names:
        nixpkgs.lib.genAttrs names (
          name:
          pkgs.linkFarm "cachix-pin-${name}-${pkgs.stdenv.hostPlatform.system}" {
            package = pkgs.${name};
          }
        );

      # --------------------------------------------------------------------------------------------
      # Pre-commit hooks
      # --------------------------------------------------------------------------------------------
      preCommitFor =
        system:
        import ./lib/pre-commit.nix {
          inherit inputs repoLib;
          pkgs = pkgsFor system;
        };

      # --------------------------------------------------------------------------------------------
      # Special args
      # --------------------------------------------------------------------------------------------
      repo = {
        root = ./.;

        modules = {
          darwin = ./modules/darwin;
          nixos = ./modules/nixos;
        };

        profiles = {
          platform = {
            cloudcone-sc2 = ./hosts/_profiles/platform/cloudcone-sc2;
            container = ./hosts/_profiles/platform/container;
            dmit = ./hosts/_profiles/platform/dmit;
            wsl = ./hosts/_profiles/platform/wsl;
          };

          role = {
            server = ./hosts/_profiles/role/server;
            workstation = ./hosts/_profiles/role/workstation;
          };
        };
      };

      repoLib = import ./lib {
        inherit (nixpkgs) lib;
        inherit (inputs) devkit;
      };

      data = import ./data;

      commonSpecialArgs = data // {
        inherit
          inputs
          repo
          repoLib
          ;
      };

      # --------------------------------------------------------------------------------------------
      # Host builders
      # --------------------------------------------------------------------------------------------
      builders = import ./lib/builders.nix {
        inherit
          inputs
          overlays
          pkgsFor
          commonSpecialArgs
          ;
      };

      inherit (builders)
        mkServer
        mkWSL
        mkDarwin
        mkSystemManager
        mkDocker
        ;
    in
    {
      # --------------------------------------------------------------------------------------------
      # NixOS Configurations (Linux servers + WSL workstation)
      # --------------------------------------------------------------------------------------------
      nixosConfigurations = self.colmenaHive.nodes // {
        wsl = mkWSL {
          flakeConfigName = "wsl";
          hostName = "wsl";
          hostType = "work";
          hostModule = ./hosts/workstations/work/wsl;
        };
      };

      # --------------------------------------------------------------------------------------------
      # Colmena (multi-server deployment)
      # --------------------------------------------------------------------------------------------
      colmena = {
        meta = {
          nixpkgs = pkgsFor "x86_64-linux";
          specialArgs = commonSpecialArgs;

          nodeSpecialArgs = builtins.mapAttrs (_: server: {
            hostName = server.name;
            hostType = "personal";
          }) data.servers;
        };

        # Colmena uses eval-config directly, so retain nixosSystem's flake metadata.
        defaults = {
          nixpkgs.flake.source = nixpkgs.outPath;

          system.nixos = {
            inherit (nixpkgs.lib.trivial) versionSuffix;
            revision = nixpkgs.lib.trivial.revisionWithDefault null;
          };
        };
      }
      // builtins.mapAttrs (
        name: server:
        (mkServer {
          flakeConfigName = name;
          hostName = server.name;
          hostType = "personal";
          hostModule = ./hosts/servers + "/${name}";
        })
        // {
          deployment = {
            targetHost = server.displayName;
            targetUser = "hakula";
            buildOnTarget = true;
            tags = [ (nixpkgs.lib.toLower server.provider) ];
          };
        }
      ) data.servers;

      colmenaHive = inputs.colmena.lib.makeHive self.colmena;

      # --------------------------------------------------------------------------------------------
      # Darwin Configurations (macOS)
      # --------------------------------------------------------------------------------------------
      darwinConfigurations = {
        macbook = mkDarwin {
          displayName = "Hakula-MacBook";
          flakeConfigName = "macbook";
          hostName = "hakula-macbook";
          hostType = "personal";
          hostModule = ./hosts/workstations/personal/macbook;
        };
      };

      # --------------------------------------------------------------------------------------------
      # System Manager Configurations (non-NixOS Linux)
      # --------------------------------------------------------------------------------------------
      systemConfigs = {
        wsl-non-nixos = mkSystemManager {
          flakeConfigName = "wsl-non-nixos";
          hostName = "wsl-non-nixos";
          hostType = "work";
          hostModule = ./hosts/workstations/work/wsl-non-nixos;
        };
      };

      # --------------------------------------------------------------------------------------------
      # Packages
      # --------------------------------------------------------------------------------------------
      packages = {
        x86_64-linux.system-manager = (pkgsFor "x86_64-linux").system-manager;

        x86_64-linux.devvm-docker = mkDocker {
          flakeConfigName = null;
          hostName = "devvm";
          hostType = "work";
          hostModule = ./hosts/images/devvm;
        };
      };

      # --------------------------------------------------------------------------------------------
      # Cachix pins
      # --------------------------------------------------------------------------------------------
      cachixPins = {
        us-1 = mkCachixPins self.nixosConfigurations.us-1.pkgs [
          "peertube"
        ];

        wsl = mkCachixPins self.nixosConfigurations.wsl.pkgs [
          "wakatime-cli"
        ];

        macbook = mkCachixPins self.darwinConfigurations.macbook.pkgs [
          "peertube-runner"
          "thaw"
          "wakatime-cli"
        ];
      };

      # --------------------------------------------------------------------------------------------
      # Checks
      # --------------------------------------------------------------------------------------------
      checks = forAllSystems (
        system:
        import ./tests {
          inherit inputs repoLib;
          pkgs = pkgsFor system;
        }
      );

      # --------------------------------------------------------------------------------------------
      # Dev shells
      # --------------------------------------------------------------------------------------------
      devShells = forAllSystems (
        system:
        import ./lib/dev-shells.nix {
          pkgs = pkgsFor system;
          preCommit = preCommitFor system;
        }
      );

      # --------------------------------------------------------------------------------------------
      # Formatter (nix fmt)
      # --------------------------------------------------------------------------------------------
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
    };
}
