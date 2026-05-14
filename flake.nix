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
      nix-darwin,
      home-manager,
      system-manager,
      disko,
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
        inputs.rust-overlay.overlays.default
        (final: _: {
          unstable = import nixpkgs-unstable {
            localSystem = final.stdenv.hostPlatform.system;
            config.allowUnfree = true;
          };

          agenix = agenix.packages.${final.stdenv.hostPlatform.system}.default;
          system-manager = system-manager.packages.${final.stdenv.hostPlatform.system}.default;
          cloudreve = final.callPackage ./packages/cloudreve { };
          mcp-server-filesystem = final.callPackage ./packages/mcp/mcp-server-filesystem { };
          mcp-server-git = final.callPackage ./packages/mcp/mcp-server-git { };
          mcp-server-github = final.callPackage ./packages/mcp/mcp-server-github { };
          mcp-server-gitlab = final.callPackage ./packages/mcp/mcp-server-gitlab { };
          peertube = final.unstable.peertube.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [
              ./packages/peertube/cdn-redirect-runner.patch
              ./packages/peertube/hq-transcode.patch
              ./packages/peertube/runner-download-timeout.patch
            ];
            meta = old.meta // {
              platforms = old.meta.platforms ++ [ "aarch64-darwin" ];
            };
          });
          peertube-runner = final.callPackage ./packages/peertube/runner.nix { };
          rustToolchain = final.rust-bin.stable.latest.default.override {
            extensions = [
              "llvm-tools-preview"
              "rust-analyzer"
              "rust-src"
            ];
          };
          zsh-hist = final.callPackage ./packages/zsh-hist { };
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
            end-of-file-fixer = {
              enable = true;
              excludes = [ "\\.age$" ];
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
            nixfmt.enable = true;
            statix.enable = true;
            deadnix.enable = true;
          };
        };

      secrets = import ./lib/secrets.nix { inherit (nixpkgs) lib; };
      keys = import ./secrets/keys.nix;
      caches = import ./lib/caches.nix;
      corpDomain = import ./lib/corp-domain.nix;
      llmAssistantLib = import ./lib/llm-assistants { inherit (nixpkgs) lib; };
      repoModules = {
        nixos = ./modules/nixos;
      };
      sharedConfig = { pkgs, lib }: import ./modules/shared.nix { inherit pkgs lib; };
      toolingFor = pkgs: import ./lib/tooling.nix { inherit pkgs; };
      commonSpecialArgs = {
        inherit
          inputs
          secrets
          keys
          caches
          corpDomain
          llmAssistantLib
          repoModules
          sharedConfig
          toolingFor
          ;
      };

      # Shared Home Manager integration block used by mkServer, mkDarwin, and mkDocker
      mkHomeManagerConfig =
        {
          username ? "hakula",
          isNixOS,
          isDesktop,
          enableDevToolchains ? false,
          systemManagerConfigName ? null,
        }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.${username} = import ./home/hakula.nix;
            backupFileExtension = "bak";
            extraSpecialArgs = {
              inherit
                inputs
                secrets
                caches
                corpDomain
                llmAssistantLib
                sharedConfig
                toolingFor
                username
                isNixOS
                isDesktop
                enableDevToolchains
                systemManagerConfigName
                ;
            };
          };
        };

      # Shared modules for all NixOS servers (used by mkServer and Colmena)
      serverSharedModules = [
        agenix.nixosModules.default
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        (mkHomeManagerConfig {
          isNixOS = true;
          isDesktop = false;
        })
      ];

      # ------------------------------------------------------------------------
      # Server Configuration
      # ------------------------------------------------------------------------
      mkServer =
        {
          hostName,
          configPath,
        }:
        nixpkgs.lib.nixosSystem {
          specialArgs = commonSpecialArgs // {
            inherit hostName;
          };
          modules = [
            {
              nixpkgs.hostPlatform = "x86_64-linux";
              nixpkgs.overlays = overlays;
            }
          ]
          ++ serverSharedModules
          ++ [ configPath ];
        };

      # ------------------------------------------------------------------------
      # Darwin Configuration
      # ------------------------------------------------------------------------
      mkDarwin =
        {
          hostName,
          displayName,
          configPath,
        }:
        nix-darwin.lib.darwinSystem {
          specialArgs = commonSpecialArgs // {
            inherit
              hostName
              displayName
              ;
          };
          modules = [
            {
              nixpkgs.hostPlatform = "aarch64-darwin";
              nixpkgs.overlays = overlays;
            }
            agenix.darwinModules.default
            home-manager.darwinModules.home-manager
            (mkHomeManagerConfig {
              isNixOS = false;
              isDesktop = true;
              enableDevToolchains = true;
            })
            configPath
          ];
        };

      # ------------------------------------------------------------------------
      # System Manager Configuration (non-NixOS Linux)
      # ------------------------------------------------------------------------
      mkSystemManager =
        {
          hostName,
          configPath,
          username ? "hakula",
          isDesktop ? false,
          enableDevToolchains ? true,
        }:
        system-manager.lib.makeSystemConfig {
          modules = [
            {
              nixpkgs.hostPlatform = "x86_64-linux";
              nixpkgs.config.allowUnfree = true;
            }
            home-manager.nixosModules.home-manager
            (mkHomeManagerConfig {
              inherit
                username
                isDesktop
                enableDevToolchains
                ;
              isNixOS = false;
              systemManagerConfigName = hostName;
            })
            ./modules/system-manager
            configPath
          ];
          inherit overlays;
          specialArgs = commonSpecialArgs // {
            inherit hostName;
          };
        };

      # ------------------------------------------------------------------------
      # Docker Configuration
      # ------------------------------------------------------------------------
      mkDocker =
        {
          name,
          tag ? "latest",
          configPath,
          username ? "hakula",
          enableDevToolchains ? false,
        }:
        let
          pkgs = pkgsFor "x86_64-linux";
          nixosConfig = nixpkgs.lib.nixosSystem {
            specialArgs = commonSpecialArgs;
            modules = [
              {
                nixpkgs.hostPlatform = "x86_64-linux";
                nixpkgs.overlays = overlays;
              }
              agenix.nixosModules.default
              home-manager.nixosModules.home-manager
              (mkHomeManagerConfig {
                inherit username enableDevToolchains;
                isNixOS = true;
                isDesktop = false;
              })
              configPath
            ];
          };
          inherit (nixosConfig.config.system.build) toplevel;
        in
        pkgs.dockerTools.buildLayeredImageWithNixDb {
          inherit name tag;
          contents = [ toplevel ];
          config = {
            Cmd = [ "${toplevel}/init" ];
          };
        };
    in
    {
      # ------------------------------------------------------------------------
      # NixOS Configurations (Linux servers)
      # ------------------------------------------------------------------------
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
        # US-4 (DMIT)
        # ----------------------------------------------------------------------
        us-4 = mkServer {
          hostName = "us-4";
          configPath = ./hosts/us-4;
        };

        # ----------------------------------------------------------------------
        # SG-1 (Tencent Lighthouse)
        # ----------------------------------------------------------------------
        sg-1 = mkServer {
          hostName = "sg-1";
          configPath = ./hosts/sg-1;
        };
      };

      # ------------------------------------------------------------------------
      # Colmena (multi-server deployment)
      # ------------------------------------------------------------------------
      colmena =
        let
          servers = import ./lib/servers.nix;
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
          imports = [ (./hosts + "/${name}") ];
        }) servers;

      # ------------------------------------------------------------------------
      # Darwin Configurations (macOS)
      # ------------------------------------------------------------------------
      darwinConfigurations = {
        # ----------------------------------------------------------------------
        # Hakula's MacBook Pro
        # ----------------------------------------------------------------------
        hakula-macbook = mkDarwin {
          hostName = "hakula-macbook";
          displayName = "Hakula-MacBook";
          configPath = ./hosts/hakula-macbook;
        };
      };

      # ------------------------------------------------------------------------
      # System Manager Configurations (non-NixOS Linux)
      # ------------------------------------------------------------------------
      systemConfigs = {
        # ----------------------------------------------------------------------
        # Hakula's Generic Linux workstation
        # ----------------------------------------------------------------------
        hakula-linux = mkSystemManager {
          hostName = "hakula-linux";
          configPath = ./hosts/hakula-linux;
        };
      };

      # ------------------------------------------------------------------------
      # Packages
      # ------------------------------------------------------------------------
      packages = {
        # ----------------------------------------------------------------------
        # Docker Images (for air-gapped deployment)
        # ----------------------------------------------------------------------
        x86_64-linux.hakula-devvm-docker = mkDocker {
          name = "hakula-devvm";
          configPath = ./hosts/hakula-devvm;
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
