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
    agenix = {
      url = "github:ryantm/agenix";
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
    agent-project-move = {
      url = "github:hakula139/agent-project-move/v0.1.0";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-unstable.follows = "nixpkgs-unstable";
        home-manager.follows = "home-manager";
        git-hooks-nix.follows = "git-hooks-nix";
      };
    };

    devkit = {
      url = "github:hakula139/devkit/e0d835ba91cf38c7f6d950c8a56c0d68e74366bd";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-unstable.follows = "nixpkgs-unstable";
        git-hooks-nix.follows = "git-hooks-nix";
      };
    };

    listenbrainz-scrobbler = {
      url = "github:hakula139/listenbrainz-scrobbler/v0.3.0";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        git-hooks-nix.follows = "git-hooks-nix";
      };
    };

    oxide-code = {
      url = "github:hakula139/oxide-code/v0.1.0-alpha.10";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        git-hooks-nix.follows = "git-hooks-nix";
      };
    };

    plugins = {
      url = "github:hakula139/plugins/9e54c8ecb47a91d7c52ff58d23379369b2a29d58";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        devkit.follows = "devkit";
      };
    };
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
        inherit inputs repoLib;
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
      # Pre-commit checks
      # --------------------------------------------------------------------------------------------
      preCommitCheckFor =
        system:
        import ./lib/pre-commit.nix {
          pkgs = pkgsFor system;
          inherit inputs;
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
      };

      data = import ./data;
      keys = import ./secrets/keys.nix;

      commonSpecialArgs = data // {
        inherit
          inputs
          repo
          repoLib
          keys
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
          enableDevToolchains = true;
          username = "root";
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
      checks = forAllSystems (system: {
        pre-commit = preCommitCheckFor system;

        scripts = import ./lib/script-tests.nix {
          pkgs = pkgsFor system;
          root = ./.;
        };
      });

      # --------------------------------------------------------------------------------------------
      # Dev shells
      # --------------------------------------------------------------------------------------------
      devShells = forAllSystems (
        system:
        import ./lib/dev-shells.nix {
          pkgs = pkgsFor system;
          preCommitCheck = preCommitCheckFor system;
        }
      );

      # --------------------------------------------------------------------------------------------
      # Formatter (nix fmt)
      # --------------------------------------------------------------------------------------------
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
    };
}
