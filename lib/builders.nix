# ==================================================================================================
# Host Builders
# ==================================================================================================

{
  inputs,
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

  # ------------------------------------------------------------------------------------------------
  # Home Manager integration
  # ------------------------------------------------------------------------------------------------
  mkHomeManagerConfig =
    {
      flakeConfigName,
      hostName,
      hostType,
      isDesktop,
      isNixOS,
      enableDevToolchains ? false,
    }:
    { config, ... }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${config.hakula.user.name} = import ../home/hakula.nix;
        backupFileExtension = "bak";
        extraSpecialArgs = commonSpecialArgs // {
          inherit
            flakeConfigName
            hostName
            hostType
            isDesktop
            isNixOS
            enableDevToolchains
            ;
          username = config.hakula.user.name;
        };
      };
    };

  # ------------------------------------------------------------------------------------------------
  # Shared NixOS modules
  # ------------------------------------------------------------------------------------------------
  mkNixosBaseModules = homeManagerArgs: [
    agenix.nixosModules.default
    home-manager.nixosModules.home-manager
    (mkHomeManagerConfig homeManagerArgs)
    { _module.args = { inherit (homeManagerArgs) isDesktop; }; }
  ];

  # ------------------------------------------------------------------------------------------------
  # NixOS system
  # ------------------------------------------------------------------------------------------------
  mkNixosSystem =
    {
      flakeConfigName,
      hostName,
      hostType,
      hostModule,
      isDesktop,
      enableDevToolchains,
    }:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = commonSpecialArgs // {
        inherit hostName hostType;
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
          hostType
          isDesktop
          ;
        isNixOS = true;
      }
      ++ [ hostModule ];
    };

  # ------------------------------------------------------------------------------------------------
  # Server (NixOS)
  # ------------------------------------------------------------------------------------------------
  mkServer =
    {
      flakeConfigName,
      hostName,
      hostType,
      hostModule,
    }:
    {
      nixpkgs.hostPlatform = "x86_64-linux";
      imports =
        mkNixosBaseModules {
          inherit
            flakeConfigName
            hostName
            hostType
            ;
          isDesktop = false;
          isNixOS = true;
        }
        ++ [
          disko.nixosModules.disko
          hostModule
        ];
    };

  # ------------------------------------------------------------------------------------------------
  # WSL workstation (NixOS-WSL)
  # ------------------------------------------------------------------------------------------------
  mkWSL =
    {
      flakeConfigName,
      hostName,
      hostType,
      hostModule,
    }:
    mkNixosSystem {
      inherit
        flakeConfigName
        hostName
        hostType
        hostModule
        ;
      isDesktop = true;
      enableDevToolchains = true;
    };

  # ------------------------------------------------------------------------------------------------
  # Darwin (macOS)
  # ------------------------------------------------------------------------------------------------
  mkDarwin =
    {
      displayName,
      flakeConfigName,
      hostName,
      hostType,
      hostModule,
    }:
    nix-darwin.lib.darwinSystem {
      specialArgs = commonSpecialArgs // {
        inherit
          displayName
          hostName
          hostType
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
          inherit
            flakeConfigName
            hostName
            hostType
            ;
          isDesktop = true;
          isNixOS = false;
          enableDevToolchains = true;
        })
        hostModule
      ];
    };

  # ------------------------------------------------------------------------------------------------
  # System Manager (non-NixOS Linux)
  # ------------------------------------------------------------------------------------------------
  mkSystemManager =
    {
      flakeConfigName,
      hostName,
      hostType,
      hostModule,
    }:
    system-manager.lib.makeSystemConfig {
      modules = [
        {
          nixpkgs.hostPlatform = "x86_64-linux";
        }
        home-manager.nixosModules.home-manager
        (mkHomeManagerConfig {
          inherit
            flakeConfigName
            hostName
            hostType
            ;
          isDesktop = true;
          isNixOS = false;
          enableDevToolchains = true;
        })
        ../modules/system-manager
        hostModule
      ];
      inherit overlays;
      specialArgs = commonSpecialArgs // {
        inherit hostName hostType;
      };
    };

  # ------------------------------------------------------------------------------------------------
  # Docker image (NixOS-on-Docker for air-gapped delivery)
  # ------------------------------------------------------------------------------------------------
  mkDocker =
    {
      flakeConfigName,
      hostName,
      hostType,
      hostModule,
    }:
    let
      pkgs = pkgsFor "x86_64-linux";
      nixosConfig = mkNixosSystem {
        inherit
          flakeConfigName
          hostName
          hostType
          hostModule
          ;
        isDesktop = false;
        enableDevToolchains = true;
      };
      inherit (nixosConfig.config.system.build) toplevel;
    in
    pkgs.dockerTools.buildLayeredImageWithNixDb {
      name = hostName;
      tag = "latest";
      contents = [ toplevel ];
      config = {
        Cmd = [ "${toplevel}/init" ];
      };
    };
in
{
  inherit
    mkServer
    mkWSL
    mkDarwin
    mkSystemManager
    mkDocker
    ;
}
