{ lib, pkgs, ... }:

# ============================================================================
# Linux Configuration
# ============================================================================

let
  shared = import ./shared.nix { inherit pkgs; };
  cloudflareIPs = import ./cloudflare-ips.nix;

  # Generate nginx set_real_ip_from directives from the Cloudflare IP list
  cloudflareRealIPConfig = lib.concatMapStringsSep "\n" (ip: "set_real_ip_from ${ip};") (
    cloudflareIPs.ipv4 ++ cloudflareIPs.ipv6
  );
in
{
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

  users.users.hakula = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ shared.sshKeys.hakula ];
  };

  users.users.root.openssh.authorizedKeys.keys = [ shared.sshKeys.hakula ];

  security.sudo.wheelNeedsPassword = false;

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

  # ----------------------------------------------------------------------------
  # Web Server (nginx + ACME)
  # ----------------------------------------------------------------------------
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "i@hakula.xyz";
      dnsProvider = "cloudflare";
      environmentFile = "/var/lib/acme/cloudflare-credentials";
      dnsResolver = "1.1.1.1:53";
    };
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    clientMaxBodySize = "10G";

    commonHttpConfig = ''
      # Cloudflare IP ranges for real IP detection
      # Source: https://www.cloudflare.com/ips/ (defined in cloudflare-ips.nix)
      ${cloudflareRealIPConfig}
      real_ip_header CF-Connecting-IP;
    '';

    # Default: Reject unknown hostnames
    virtualHosts."_" = {
      default = true;
      rejectSSL = true;
      locations."/".return = "444";
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
