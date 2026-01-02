{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# NixOS Configuration
# ==============================================================================

let
  shared = import ../shared.nix { inherit pkgs; };
  keys = import ../../secrets/keys.nix;

  sshCfg = config.hakula.access.ssh;

  # REALITY SNI Host
  # If you change this, also update secrets/shared/xray-config.json.age.
  realitySniHost = "www.microsoft.com";
in
{
  imports = [
    ./aria2
    ./backup
    ./cachix
    (import ./clash { inherit realitySniHost; })
    ./cloudcone
    ./cloudreve
    ./dockerhub
    ./netdata
    (import ./nginx { inherit realitySniHost; })
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
    # Nix
    # --------------------------------------------------------------------------
    nix = {
      settings =
        shared.nixSettings
        // lib.optionalAttrs config.hakula.services.cachix.enable {
          inherit (shared.cachix.caches) substituters trusted-public-keys;
        };

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
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
          # Note: SSH port is auto-opened by services.openssh
        ];
      };
    };

    # --------------------------------------------------------------------------
    # Users & Security
    # --------------------------------------------------------------------------
    users.defaultUserShell = pkgs.zsh;

    users.users.root.openssh.authorizedKeys.keys = sshCfg.authorizedKeys;

    users.users.hakula = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = sshCfg.authorizedKeys;
    };

    security.sudo.wheelNeedsPassword = false;

    # --------------------------------------------------------------------------
    # Environment
    # --------------------------------------------------------------------------
    programs.zsh.enable = true;
    environment.shells = [ pkgs.zsh ];

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
  };
}
