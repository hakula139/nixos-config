{
  pkgs,
  lib,
  ...
}:

# ============================================================================
# NixOS Configuration
# ============================================================================

let
  shared = import ../shared.nix { inherit pkgs; };

  # REALITY SNI Host
  # If you change this, also update secrets/xray-config.json.age.
  realitySniHost = "www.microsoft.com";
in
{
  imports = [
    ./netdata
    ./xray
    (import ./clash { inherit realitySniHost; })
    (import ./nginx { inherit realitySniHost; })
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
  # Secrets (agenix)
  # ============================================================================
  age.secrets.cachix-auth-token = {
    file = ../../secrets/cachix-auth-token.age;
    owner = "hakula";
    group = "users";
    mode = "0400";
  };

  age.secrets.cloudflare-credentials = {
    file = ../../secrets/cloudflare-credentials.age;
    owner = "acme";
    group = "acme";
    mode = "0400";
  };

  # ============================================================================
  # Services
  # ============================================================================

  # ----------------------------------------------------------------------------
  # SSH
  # ----------------------------------------------------------------------------
  services.openssh = {
    enable = true;
    ports = [ 35060 ];
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };


  # ============================================================================
  # Environment
  # ============================================================================
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];

  environment.variables = {
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
  };

  fonts = {
    packages = shared.fonts;
    fontconfig.enable = true;
  };

  environment.systemPackages = shared.basePackages ++ shared.nixTooling;

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
