{
  config,
  pkgs,
  lib,
  secrets,
  ...
}:

# ==============================================================================
# NixOS Configuration
# ==============================================================================

let
  shared = import ../shared.nix { inherit pkgs; };
  keys = import ../../secrets/keys.nix;

  cfg = config.hakula;
  sshCfg = cfg.access.ssh;
  userCfg = config.users.users.${cfg.user.name};

  # REALITY SNI Host
  # If you change this, also update secrets/shared/xray-config.json.age.
  realitySniHost = "www.microsoft.com";
in
{
  imports = [
    ./aria2
    ./backup
    ./builders
    ./cachix
    ./clash
    ./claude-code
    ./cloudcone
    ./cloudreve
    ./clove
    ./dockerhub
    ./fuclaude
    ./mcp
    ./netdata
    ./nginx
    ./piclist
    ./podman
    ./postgresql
    ./ssh
    ./umami
    ./xray
  ];

  config._module.args.realitySniHost = realitySniHost;

  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.user = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "hakula";
      description = "Primary user account name";
    };
  };

  options.hakula.access.ssh = {
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = builtins.attrValues keys.users;
      description = "SSH public keys authorized for user login";
    };
  };

  config = {
    # --------------------------------------------------------------------------
    # Core System
    # --------------------------------------------------------------------------
    time.timeZone = "Asia/Shanghai";

    i18n = {
      defaultLocale = "en_US.UTF-8";
      supportedLocales = [ "en_US.UTF-8/UTF-8" ];
      extraLocaleSettings.LC_ALL = "en_US.UTF-8";
    };

    console.keyMap = "us";

    # --------------------------------------------------------------------------
    # Nix Configuration
    # --------------------------------------------------------------------------
    nix = {
      settings =
        shared.nixSettings
        // lib.optionalAttrs config.hakula.cachix.enable {
          inherit (shared.cachix.caches) substituters trusted-public-keys;
        };

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
      optimise.automatic = true;
    };

    nixpkgs.config.allowUnfree = true;

    # --------------------------------------------------------------------------
    # Boot & Kernel
    # --------------------------------------------------------------------------
    boot.kernel.sysctl = lib.mkDefault {
      # TCP BBR: Better throughput on high-latency / lossy networks
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
      # Memory: Reduce swap usage on memory-constrained servers
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
    };

    # --------------------------------------------------------------------------
    # Disk Optimization
    # --------------------------------------------------------------------------
    # Limit journal size to prevent excessive disk usage
    services.journald.extraConfig = ''
      SystemMaxUse=200M
      MaxRetentionSec=7day
    '';

    # --------------------------------------------------------------------------
    # Networking
    # --------------------------------------------------------------------------
    networking = {
      domain = lib.mkDefault "hakula.xyz";
      firewall = {
        enable = lib.mkDefault true;
        allowPing = lib.mkDefault true;
        allowedTCPPorts = [
          80
          443
        ];
      };
    };

    # --------------------------------------------------------------------------
    # Users & Security
    # --------------------------------------------------------------------------
    users.defaultUserShell = pkgs.zsh;

    users.users = {
      root.openssh.authorizedKeys.keys = lib.mkDefault (sshCfg.authorizedKeys ++ [ keys.builder ]);
    }
    // lib.optionalAttrs (cfg.user.name != "root") {
      ${cfg.user.name} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = lib.mkDefault sshCfg.authorizedKeys;
        linger = lib.mkDefault true;
      };
    };

    security.sudo.wheelNeedsPassword = false;

    # --------------------------------------------------------------------------
    # Environment
    # --------------------------------------------------------------------------
    programs.zsh.enable = true;
    environment.shells = [ pkgs.zsh ];

    # /bin/bash symlink for scripts with #!/bin/bash shebangs
    system.activationScripts.binbash.text = ''
      mkdir -p /bin
      ln -sfn ${pkgs.bash}/bin/bash /bin/bash
    '';

    environment.variables = {
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
    };

    environment.systemPackages = shared.basePackages;

    fonts = {
      packages = shared.fonts;
      fontconfig.enable = true;
    };

    # Nix-LD: Run unpatched Linux binaries
    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      curl
      glib
      glibc
      icu
      libkrb5
      libsecret
      libunwind
      libuuid
      openssl
      stdenv.cc.cc.lib
      util-linux
      zlib
    ];

    # --------------------------------------------------------------------------
    # Secrets Configuration (agenix)
    # --------------------------------------------------------------------------
    systemd.tmpfiles.rules = secrets.mkSecretsDir userCfg userCfg.group;
  };
}
