{
  config,
  lib,
  pkgs,
  ...
}:

# ============================================================================
# NixOS Configuration
# ============================================================================

let
  shared = import ../shared.nix { inherit pkgs; };

  cloudflareIPs = import ./cloudflare-ips.nix;
  cloudflareRealIPConfig = lib.concatMapStringsSep "\n" (ip: "set_real_ip_from ${ip};") (
    cloudflareIPs.ipv4 ++ cloudflareIPs.ipv6
  );

  subconverterPort = 25500;
  subconverterPkg = pkgs.callPackage ../../pkgs/subconverter.nix { };
  subconverterPref = pkgs.writeText "subconverter-pref.ini" ''
    [common]
    api_mode = true
    api_access_token = ""
    listen = 127.0.0.1
    port = ${toString subconverterPort}
  '';
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

  users.users.acme = {
    isSystemUser = true;
    group = "acme";
  };
  users.groups.acme = { };

  users.users.sing-box = {
    isSystemUser = true;
    group = "sing-box";
  };
  users.groups.sing-box = { };

  users.users.subconverter = {
    isSystemUser = true;
    group = "subconverter";
  };
  users.groups.subconverter = { };

  security.sudo.wheelNeedsPassword = false;

  # ============================================================================
  # Secrets (agenix)
  # ============================================================================
  age.secrets.cloudflare-credentials = {
    file = ../../secrets/cloudflare-credentials.age;
    owner = "acme";
    group = "acme";
    mode = "0400";
  };

  age.secrets.sing-box-config = {
    file = ../../secrets/sing-box-config.age;
    owner = "sing-box";
    group = "sing-box";
    mode = "0440";
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

  # ----------------------------------------------------------------------------
  # Proxy (sing-box with VLESS + REALITY)
  # ----------------------------------------------------------------------------
  systemd.services.sing-box = {
    description = "sing-box service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.sing-box}/bin/sing-box run -c ${config.age.secrets.sing-box-config.path}";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "sing-box";
      Group = "sing-box";
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      StateDirectory = "sing-box";
      WorkingDirectory = "/var/lib/sing-box";
    };
  };

  # ----------------------------------------------------------------------------
  # Clash Subscription Converter (subconverter)
  # ----------------------------------------------------------------------------
  systemd.services.subconverter = {
    description = "clash subscription converter";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${subconverterPkg}/bin/subconverter -cf ${subconverterPref} -p ${toString subconverterPort}";
      User = "subconverter";
      Group = "subconverter";
      Restart = "on-failure";
      RestartSec = "5s";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      StateDirectory = "subconverter";
      WorkingDirectory = "/var/lib/subconverter";
    };
  };

  # ----------------------------------------------------------------------------
  # Web Server (nginx + ACME)
  # ----------------------------------------------------------------------------
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

    # Default: Reject unknown hostnames (HTTP only, 443 is used by sing-box)
    virtualHosts."_" = {
      default = true;
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
        {
          addr = "[::]";
          port = 80;
        }
      ];
      locations."/".return = "444";
    };

    virtualHosts."clash.hakula.xyz" = {
      enableACME = true;
      forceSSL = true;
      acmeRoot = null;
      locations."/".proxyPass = "http://127.0.0.1:${toString subconverterPort}";
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "i@hakula.xyz";
      dnsProvider = "cloudflare";
      environmentFile = config.age.secrets.cloudflare-credentials.path;
      dnsResolver = "1.1.1.1:53";
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
