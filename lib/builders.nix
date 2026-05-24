# ==============================================================================
# Host Builders
# ==============================================================================

{
  inputs,
  nixpkgs,
  overlays,
  pkgsFor,
  commonSpecialArgs,
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
      flakeConfigName,
      hostName,
      isDesktop,
      isNixOS,
      enableDevToolchains ? false,
      username ? "hakula",
    }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${username} = import ../home/hakula.nix;
        backupFileExtension = "bak";
        extraSpecialArgs = commonSpecialArgs // {
          inherit
            flakeConfigName
            hostName
            isDesktop
            isNixOS
            enableDevToolchains
            username
            ;
        };
      };
    };

  # ----------------------------------------------------------------------------
  # Shared NixOS modules
  # ----------------------------------------------------------------------------
  mkNixosBaseModules = homeManagerArgs: [
    agenix.nixosModules.default
    home-manager.nixosModules.home-manager
    (mkHomeManagerConfig homeManagerArgs)
  ];

  serverSharedModules =
    {
      flakeConfigName,
      hostName,
    }:
    mkNixosBaseModules {
      inherit
        flakeConfigName
        hostName
        ;
      isDesktop = false;
      isNixOS = true;
    }
    ++ [ disko.nixosModules.disko ];

  # ----------------------------------------------------------------------------
  # Server (NixOS)
  # ----------------------------------------------------------------------------
  mkServer =
    {
      flakeConfigName,
      hostName,
      hostModule,
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
      ++ serverSharedModules {
        inherit
          flakeConfigName
          hostName
          ;
      }
      ++ [ hostModule ];
    };

  # ----------------------------------------------------------------------------
  # WSL workstation (NixOS-WSL)
  # ----------------------------------------------------------------------------
  mkWSL =
    {
      flakeConfigName,
      hostName,
      hostModule,
      enableDevToolchains ? true,
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
        inherit
          enableDevToolchains
          flakeConfigName
          hostName
          ;
        isDesktop = true;
        isNixOS = true;
      }
      ++ [ hostModule ];
    };

  # ----------------------------------------------------------------------------
  # Darwin (macOS)
  # ----------------------------------------------------------------------------
  mkDarwin =
    {
      displayName,
      flakeConfigName,
      hostName,
      hostModule,
    }:
    nix-darwin.lib.darwinSystem {
      specialArgs = commonSpecialArgs // {
        inherit
          displayName
          hostName
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
          inherit
            flakeConfigName
            hostName
            ;
          isDesktop = true;
          isNixOS = false;
        })
        hostModule
      ];
    };

  # ----------------------------------------------------------------------------
  # System Manager (non-NixOS Linux)
  # ----------------------------------------------------------------------------
  mkSystemManager =
    {
      flakeConfigName,
      hostName,
      hostModule,
      enableDevToolchains ? true,
      isDesktop ? true,
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
            flakeConfigName
            hostName
            isDesktop
            ;
          isNixOS = false;
        })
        ../modules/system-manager
        hostModule
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
      flakeConfigName,
      name,
      hostModule,
      enableDevToolchains ? false,
      tag ? "latest",
      username ? "hakula",
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
          inherit
            enableDevToolchains
            flakeConfigName
            username
            ;
          hostName = name;
          isDesktop = false;
          isNixOS = true;
        }
        ++ [ hostModule ];
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
