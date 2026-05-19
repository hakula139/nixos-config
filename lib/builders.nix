# ==============================================================================
# Host Builders
# ==============================================================================

{
  inputs,
  nixpkgs,
  overlays,
  pkgsFor,
  commonSpecialArgs,
  commonExtraSpecialArgs,
}:

let
  inherit (inputs)
    agenix
    disko
    home-manager
    nix-darwin
    system-manager
    ;

  # ----------------------------------------------------------------------------
  # Home Manager integration
  # ----------------------------------------------------------------------------
  mkHomeManagerConfig =
    {
      enableDevToolchains ? false,
      isDesktop,
      isNixOS,
      systemManagerConfigName ? null,
      username ? "hakula",
    }:
    {
      hostName ? null,
      ...
    }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${username} = import ../home/hakula.nix;
        backupFileExtension = "bak";
        extraSpecialArgs = commonExtraSpecialArgs // {
          inherit
            enableDevToolchains
            hostName
            isDesktop
            isNixOS
            systemManagerConfigName
            username
            ;
        };
      };
    };

  # ----------------------------------------------------------------------------
  # Shared NixOS modules
  # ----------------------------------------------------------------------------
  # Modules every NixOS system in this flake imports: agenix, home-manager,
  # and the home-manager glue. `disko` is added on top for hosts that
  # actually partition disks (servers); WSL ships its own VHDX and
  # mkDocker layers on `dockerTools` instead.
  mkNixosBaseModules = homeManagerArgs: [
    agenix.nixosModules.default
    home-manager.nixosModules.home-manager
    (mkHomeManagerConfig homeManagerArgs)
  ];

  serverSharedModules =
    mkNixosBaseModules {
      isDesktop = false;
      isNixOS = true;
    }
    ++ [ disko.nixosModules.disko ];

  # ----------------------------------------------------------------------------
  # Server (NixOS)
  # ----------------------------------------------------------------------------
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

  # ----------------------------------------------------------------------------
  # WSL workstation (NixOS-WSL)
  # ----------------------------------------------------------------------------
  # Like mkServer but `isDesktop = true` (cursor extensions install at
  # activation) and no disko (NixOS-WSL ships its own VHDX).
  mkWSL =
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
      ++ mkNixosBaseModules {
        isDesktop = true;
        isNixOS = true;
      }
      ++ [ configPath ];
    };

  # ----------------------------------------------------------------------------
  # Darwin (macOS)
  # ----------------------------------------------------------------------------
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
          enableDevToolchains = true;
          isDesktop = true;
          isNixOS = false;
        })
        configPath
      ];
    };

  # ----------------------------------------------------------------------------
  # System Manager (non-NixOS Linux)
  # ----------------------------------------------------------------------------
  mkSystemManager =
    {
      hostName,
      configPath,
      isDesktop ? true,
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
            enableDevToolchains
            isDesktop
            ;
          isNixOS = false;
          systemManagerConfigName = hostName;
        })
        ../modules/system-manager
        configPath
      ];
      inherit overlays;
      specialArgs = commonSpecialArgs // {
        inherit hostName;
      };
    };

  # ----------------------------------------------------------------------------
  # Docker image (NixOS-on-Docker for air-gapped delivery)
  # ----------------------------------------------------------------------------
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
        specialArgs = commonSpecialArgs // {
          hostName = name;
        };
        modules = [
          {
            nixpkgs.hostPlatform = "x86_64-linux";
            nixpkgs.overlays = overlays;
          }
        ]
        ++ mkNixosBaseModules {
          inherit enableDevToolchains username;
          isDesktop = false;
          isNixOS = true;
        }
        ++ [ configPath ];
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
  inherit
    mkHomeManagerConfig
    serverSharedModules
    mkServer
    mkWSL
    mkDarwin
    mkSystemManager
    mkDocker
    ;
}
