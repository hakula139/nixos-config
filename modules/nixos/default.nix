# ==============================================================================
# NixOS Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  secrets,
  keys,
  sharedConfig,
  ...
}:

let
  cfg = config.hakula;
  sshCfg = cfg.access.ssh;
  userConfig = config.users.users.${cfg.user.name};
  homeConfig = config.home-manager.users.${cfg.user.name} or { };

  shared = sharedConfig { inherit pkgs lib; };
in
{
  imports = [
    ./aria2
    ./backup
    ./builders
    ./cachix
    ./clash
    ./cloudcone
    ./cloudreve
    ./clove
    ./dockerhub
    ./fhs-compat
    ./fuclaude
    ./llm-assistants
    ./netdata
    ./nginx
    ./peertube
    ./piclist
    ./podman
    ./postgresql
    ./ssh
    ./umami
    ./xray
  ];

  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.access.ssh = {
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorized for user login";
    };
  };

  options.hakula.network = {
    realitySniHost = lib.mkOption {
      type = lib.types.str;
      default = "www.microsoft.com";
      description = ''
        REALITY SNI host used for TLS camouflage in Xray and SNI-based routing in nginx.
        If you change this, also update secrets/xray/config.json.age.
      '';
    };
  };

  options.hakula.user.name = lib.mkOption {
    type = lib.types.str;
    default = "hakula";
    description = "Primary user account name";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
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
          inherit (shared.binaryCaches) substituters trusted-public-keys;
        };

      gc = {
        automatic = true;
        dates = "daily";
        options = "--delete-older-than 7d";
      };
      optimise.automatic = true;
    };

    nixpkgs.config.allowUnfree = true;

    # --------------------------------------------------------------------------
    # Boot & Kernel
    # --------------------------------------------------------------------------
    boot.kernel.sysctl = {
      # TCP BBR: Better throughput on high-latency / lossy networks
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
      # Memory: Reduce swap usage on memory-constrained servers
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
    };

    # CVE-2026-31431 ("Copy Fail"): drop once nixos-25.11 ships linux_6_12 >= 6.12.85.
    boot.extraModprobeConfig = ''
      install algif_aead /run/current-system/sw/bin/false
    '';

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
      domain = "hakula.xyz";
      firewall = {
        enable = true;
        allowPing = true;
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
      root.openssh.authorizedKeys.keys = sshCfg.authorizedKeys ++ [ keys.builder ];
    }
    // lib.optionalAttrs (cfg.user.name != "root") {
      ${cfg.user.name} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = sshCfg.authorizedKeys;
        linger = true;
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

    # Nix-LD: Run unpatched Linux binaries
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
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
    };

    # --------------------------------------------------------------------------
    # Fonts & Packages
    # --------------------------------------------------------------------------
    fonts = {
      packages = shared.fonts;
      fontconfig.enable = true;
    };
    environment.systemPackages = shared.basePackages;

    # --------------------------------------------------------------------------
    # Secrets Configuration (agenix)
    # --------------------------------------------------------------------------
    age.secrets = secrets.mkRequiredUserSecrets {
      inherit homeConfig userConfig;
    };
  };
}
