# ==============================================================================
# NixOS Configuration Flake
# ==============================================================================

{
  description = "NixOS configuration for Hakula's machines";

  # ----------------------------------------------------------------------------
  # Inputs
  # ----------------------------------------------------------------------------
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    system-manager = {
      url = "github:numtide/system-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents.url = "github:numtide/llm-agents.nix";

    anthropics-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };

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
        let
          pkgs = pkgsFor system;
        in
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

            editorconfig-checker.enable = true;

            end-of-file-fixer = {
              enable = true;
              excludes = [ "\\.age$" ];
            };

            markdownlint = {
              enable = true;
              args = [ "--fix" ];
            };

            nixfmt.enable = true;

            nu-check = {
              enable = true;
              name = "nu-check";
              description = "Run nushell's diagnostic check on .nu files.";
              entry = "${pkgs.nu-check}";
              files = "\\.nu$";
              types = [ "file" ];
            };

            statix.enable = true;

            # `shfmt` reads `.editorconfig` only when the entry passes no
            # formatting flag. Any flag reverts it to tabs and ignores the
            # `binary_next_line` and `switch_case_indent` keys.
            shfmt = {
              enable = true;
              settings = {
                language-dialect = null;
                simplify = false;
                indent = null;
                binary-next-line = false;
                case-indent = false;
              };
            };

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
      corpHosts = import ./data/corp-hosts.nix;
      keys = import ./secrets/keys.nix;
      secrets = import ./lib/secrets.nix { inherit (nixpkgs) lib; };
      systemManagerLib = import ./data/system-manager.nix;

      llmAssistantLib = import ./lib/llm-assistants { inherit (nixpkgs) lib; };
      proxyLib = import ./lib/proxy.nix { inherit (nixpkgs) lib; };
      systemdLib = import ./lib/systemd.nix;
      sharedConfig = { pkgs, lib }: import ./modules/shared.nix { inherit pkgs lib; };
      toolingFor = pkgs: import ./lib/tooling.nix { inherit pkgs; };
      wslLib = import ./lib/wsl;

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
            wsl = ./hosts/_profiles/platform/wsl;
          };
          role = {
            server = ./hosts/_profiles/role/server;
            workstation = ./hosts/_profiles/role/workstation;
          };
        };
      };

      commonSpecialArgs = {
        inherit
          inputs
          caches
          corpHosts
          keys
          llmAssistantLib
          proxyLib
          repo
          secrets
          sharedConfig
          systemdLib
          systemManagerLib
          toolingFor
          wslLib
          ;
      };

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
          ;
      };

      inherit (builders)
        serverSharedModules
        mkServer
        mkWSL
        mkDarwin
        mkSystemManager
        mkDocker
        ;
    in
    {
      # ------------------------------------------------------------------------
      # NixOS Configurations (Linux servers + WSL workstation)
      # ------------------------------------------------------------------------
      nixosConfigurations = {
        us-1 = mkServer {
          flakeConfigName = "us-1";
          hostName = "us-1";
          hostType = "personal";
          hostModule = ./hosts/servers/us-1;
        };

        us-2 = mkServer {
          flakeConfigName = "us-2";
          hostName = "us-2";
          hostType = "personal";
          hostModule = ./hosts/servers/us-2;
        };

        us-3 = mkServer {
          flakeConfigName = "us-3";
          hostName = "us-3";
          hostType = "personal";
          hostModule = ./hosts/servers/us-3;
        };

        us-4 = mkServer {
          flakeConfigName = "us-4";
          hostName = "us-4";
          hostType = "personal";
          hostModule = ./hosts/servers/us-4;
        };

        sg-1 = mkServer {
          flakeConfigName = "sg-1";
          hostName = "sg-1";
          hostType = "personal";
          hostModule = ./hosts/servers/sg-1;
        };

        wsl = mkWSL {
          flakeConfigName = "wsl";
          hostName = "wsl";
          hostType = "work";
          hostModule = ./hosts/workstations/work/wsl;
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
            nodeSpecialArgs = builtins.mapAttrs (_: server: { hostName = server.name; }) servers;
          };

          defaults = {
            imports = [
              { nixpkgs.overlays = overlays; }
            ];
          };
        }
        // builtins.mapAttrs (name: server: {
          deployment = {
            targetHost = server.displayName;
            targetUser = "hakula";
            buildOnTarget = true;
            tags = [ (nixpkgs.lib.toLower server.provider) ];
          };
          imports =
            serverSharedModules {
              flakeConfigName = name;
              hostName = server.name;
              hostType = "personal";
            }
            ++ [ (./hosts/servers + "/${name}") ];
        }) servers;

      # ------------------------------------------------------------------------
      # Darwin Configurations (macOS)
      # ------------------------------------------------------------------------
      darwinConfigurations = {
        macbook = mkDarwin {
          displayName = "Hakula-MacBook";
          flakeConfigName = "macbook";
          hostName = "hakula-macbook";
          hostType = "personal";
          hostModule = ./hosts/workstations/personal/macbook;
        };
      };

      # ------------------------------------------------------------------------
      # System Manager Configurations (non-NixOS Linux)
      # ------------------------------------------------------------------------
      systemConfigs = {
        wsl-non-nixos = mkSystemManager {
          flakeConfigName = "wsl-non-nixos";
          hostName = "wsl-non-nixos";
          hostType = "work";
          hostModule = ./hosts/workstations/work/wsl-non-nixos;
        };
      };

      # ------------------------------------------------------------------------
      # Packages
      # ------------------------------------------------------------------------
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
            inherit (preCommitCheck) shellHook;
            buildInputs = preCommitCheck.enabledPackages ++ tooling.all;
          };
        }
      );

      # ------------------------------------------------------------------------
      # Formatter (nix fmt)
      # ------------------------------------------------------------------------
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
    };
}
