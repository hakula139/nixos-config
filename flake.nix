# ==============================================================================
# NixOS Configuration Flake
# ==============================================================================

{
  description = "NixOS configuration for Hakula's machines";

  # ----------------------------------------------------------------------------
  # Inputs
  # ----------------------------------------------------------------------------
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

    # NixOS-style system management for non-NixOS Linux hosts
    system-manager = {
      url = "github:numtide/system-manager";
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

    # Rust toolchains
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pre-commit hooks
    git-hooks-nix.url = "github:cachix/git-hooks.nix";

    # AI coding agents
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Anthropic skills
    anthropics-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };

    # OpenAI Codex skills
    openai-skills = {
      url = "github:openai/skills";
      flake = false;
    };
  };

  # ----------------------------------------------------------------------------
  # Outputs
  # ----------------------------------------------------------------------------
  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      git-hooks-nix,
      ...
    }@inputs:
    let
      # ------------------------------------------------------------------------
      # Nixpkgs
      # ------------------------------------------------------------------------
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      overlays = import ./lib/overlays.nix { inherit inputs nixpkgs-unstable; };

      pkgsFor =
        system:
        import nixpkgs {
          inherit overlays;
          localSystem = system;
          config.allowUnfree = true;
        };

      # ------------------------------------------------------------------------
      # Pre-commit checks
      # ------------------------------------------------------------------------
      preCommitCheckFor =
        system:
        git-hooks-nix.lib.${system}.run {
          src = ./.;
          hooks = {
            check-added-large-files.enable = true;
            check-yaml.enable = true;
            cspell = {
              enable = true;
              args = [
                "--no-progress"
                "--no-must-find-files"
              ];
            };
            deadnix.enable = true;
            end-of-file-fixer = {
              enable = true;
              excludes = [ "\\.age$" ];
            };
            markdownlint = {
              enable = true;
              args = [ "--fix" ];
              settings.configuration = {
                default = true;
                MD003.style = "atx";
                MD004.style = "dash";
                MD007.indent = 2;
                MD010.code_blocks = false;
                MD013 = false;
                MD024.siblings_only = true;
                MD026.punctuation = ".,;:";
                MD029.style = "ordered";
                MD033 = false;
                MD034 = false;
                MD041 = false;
                MD046.style = "fenced";
                MD048.style = "backtick";
                MD049.style = "underscore";
                MD050.style = "asterisk";
              };
            };
            nixfmt.enable = true;
            statix.enable = true;
            trim-trailing-whitespace = {
              enable = true;
              # Preserve Markdown's two-trailing-space hard-break syntax.
              args = [ "--markdown-linebreak-ext=md" ];
              excludes = [
                "\\.age$"
                "\\.patch$"
              ];
            };
          };
        };

      # ------------------------------------------------------------------------
      # Special args
      # ------------------------------------------------------------------------
      caches = import ./data/caches.nix;
      corpDomain = import ./data/corp-domain.nix;
      keys = import ./secrets/keys.nix;
      llmAssistantLib = import ./lib/llm-assistants { inherit (nixpkgs) lib; };
      proxyLib = import ./lib/proxy.nix { inherit (nixpkgs) lib; };
      repo = {
        root = ./.;
        modules = {
          darwin = ./modules/darwin;
          nixos = ./modules/nixos;
        };
        profiles = {
          platform = {
            cloudcone-sc2 = ./hosts/_profiles/platform/cloudcone-sc2;
            cloudcone-vps = ./hosts/_profiles/platform/cloudcone-vps;
            container = ./hosts/_profiles/platform/container;
            dmit = ./hosts/_profiles/platform/dmit;
            tencent-lighthouse = ./hosts/_profiles/platform/tencent-lighthouse;
          };
          role = {
            server = ./hosts/_profiles/role/server;
            workstation = ./hosts/_profiles/role/workstation;
          };
        };
      };
      secrets = import ./lib/secrets.nix { inherit (nixpkgs) lib; };
      sharedConfig = { pkgs, lib }: import ./modules/shared.nix { inherit pkgs lib; };
      systemManagerLib = import ./data/system-manager.nix;
      toolingFor = pkgs: import ./lib/tooling.nix { inherit pkgs; };
      commonSpecialArgs = {
        inherit
          inputs
          caches
          corpDomain
          keys
          llmAssistantLib
          proxyLib
          repo
          secrets
          sharedConfig
          systemManagerLib
          toolingFor
          ;
      };
      commonExtraSpecialArgs = removeAttrs commonSpecialArgs [
        "keys"
      ];

      # ------------------------------------------------------------------------
      # Host builders
      # ------------------------------------------------------------------------
      builders = import ./lib/builders.nix {
        inherit
          inputs
          nixpkgs
          overlays
          pkgsFor
          commonSpecialArgs
          commonExtraSpecialArgs
          ;
      };
      inherit (builders)
        serverSharedModules
        mkServer
        mkDarwin
        mkSystemManager
        mkDocker
        ;
    in
    {
      # ------------------------------------------------------------------------
      # NixOS Configurations (Linux servers)
      # ------------------------------------------------------------------------
      nixosConfigurations = {
        us-1 = mkServer {
          hostName = "us-1";
          configPath = ./hosts/servers/us-1;
        };

        us-2 = mkServer {
          hostName = "us-2";
          configPath = ./hosts/servers/us-2;
        };

        us-3 = mkServer {
          hostName = "us-3";
          configPath = ./hosts/servers/us-3;
        };

        us-4 = mkServer {
          hostName = "us-4";
          configPath = ./hosts/servers/us-4;
        };

        sg-1 = mkServer {
          hostName = "sg-1";
          configPath = ./hosts/servers/sg-1;
        };
      };

      # ------------------------------------------------------------------------
      # Colmena (multi-server deployment)
      # ------------------------------------------------------------------------
      colmena =
        let
          servers = import ./data/servers.nix;
        in
        {
          meta = {
            nixpkgs = import nixpkgs {
              system = "x86_64-linux";
              config.allowUnfree = true;
            };
            specialArgs = commonSpecialArgs;
            nodeSpecialArgs = builtins.mapAttrs (name: _: { hostName = name; }) servers;
          };

          defaults = {
            imports = [
              { nixpkgs.overlays = overlays; }
            ]
            ++ serverSharedModules;
          };
        }
        // builtins.mapAttrs (name: server: {
          deployment = {
            targetHost = server.displayName;
            targetUser = "hakula";
            buildOnTarget = true;
            tags = [ (nixpkgs.lib.toLower server.provider) ];
          };
          imports = [ (./hosts/servers + "/${name}") ];
        }) servers;

      # ------------------------------------------------------------------------
      # Darwin Configurations (macOS)
      # ------------------------------------------------------------------------
      darwinConfigurations = {
        macbook = mkDarwin {
          hostName = "hakula-macbook";
          displayName = "Hakula-MacBook";
          configPath = ./hosts/workstations/macbook;
        };
      };

      # ------------------------------------------------------------------------
      # System Manager Configurations (non-NixOS Linux)
      # ------------------------------------------------------------------------
      systemConfigs = {
        wsl-non-nixos = mkSystemManager {
          hostName = "wsl-non-nixos";
          configPath = ./hosts/workstations/wsl-non-nixos;
        };
      };

      # ------------------------------------------------------------------------
      # Packages
      # ------------------------------------------------------------------------
      packages = {
        x86_64-linux.system-manager = (pkgsFor "x86_64-linux").system-manager;

        # Docker images for air-gapped deployment.
        x86_64-linux.devvm-docker = mkDocker {
          name = "devvm";
          configPath = ./hosts/images/devvm;
          username = "root";
          enableDevToolchains = true;
        };
      };

      # ------------------------------------------------------------------------
      # Pre-commit Hooks (git-hooks.nix)
      # ------------------------------------------------------------------------
      checks = forAllSystems (system: {
        pre-commit = preCommitCheckFor system;
      });

      # ------------------------------------------------------------------------
      # Dev shell
      # ------------------------------------------------------------------------
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          tooling = import ./lib/tooling.nix { inherit pkgs; };
          preCommitCheck = preCommitCheckFor system;
        in
        {
          default = pkgs.mkShell {
            buildInputs = preCommitCheck.enabledPackages ++ tooling.nix ++ tooling.secrets;
            inherit (preCommitCheck) shellHook;
          };
        }
      );

      # ------------------------------------------------------------------------
      # Formatter (nix fmt)
      # ------------------------------------------------------------------------
      formatter = forAllSystems (system: (pkgsFor system).nixfmt);
    };
}
