{
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# NixOS Configuration
# ==============================================================================

let
  shared = import ../shared.nix { inherit pkgs; };

  # REALITY SNI Host
  # If you change this, also update secrets/xray-config.json.age.
  realitySniHost = "www.microsoft.com";
in
{
  imports = [
    ./aria2
    ./cachix
    (import ./clash { inherit realitySniHost; })
    ./cloudcone
    ./cloudreve
    ./dockerhub
    ./netdata
    (import ./nginx { inherit realitySniHost; })
    ./piclist
    ./postgresql
    ./ssh
    ./xray
  ];

  # ============================================================================
  # Core System
  # ============================================================================
  time.timeZone = "Asia/Shanghai";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [ "en_US.UTF-8/UTF-8" ];
    extraLocaleSettings.LC_ALL = "en_US.UTF-8";
  };

  console.keyMap = "us";

  # ============================================================================
  # Nix
  # ============================================================================
  nix = {
    settings = shared.nixSettings;
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "netdata"
    ];

  # ============================================================================
  # Boot & Kernel
  # ============================================================================
  boot.kernel.sysctl = {
    # TCP BBR: Better throughput on high-latency / lossy networks
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    # Memory: Reduce swap usage on memory-constrained servers
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
  };

  # ============================================================================
  # Networking
  # ============================================================================
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

  # ============================================================================
  # Users & Security
  # ============================================================================
  users.defaultUserShell = pkgs.zsh;

  users.users.root.openssh.authorizedKeys.keys = [ shared.sshKeys.hakula ];

  users.users.hakula = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ shared.sshKeys.hakula ];
  };

  security.sudo.wheelNeedsPassword = false;

  # ============================================================================
  # Environment
  # ============================================================================
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
}
