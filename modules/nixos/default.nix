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

  clashGenerator = import ./clash-generator { inherit config pkgs; };
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

  users.users.xray = {
    isSystemUser = true;
    group = "xray";
  };
  users.groups.xray = { };

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

  age.secrets.xray-config = {
    file = ../../secrets/xray-config.age;
    owner = "xray";
    group = "xray";
    mode = "0440";
  };

  age.secrets.clash-users = {
    file = ../../secrets/clash-users.age;
    mode = "0444";
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
  # Proxy (Xray with VLESS + REALITY)
  # ----------------------------------------------------------------------------
  systemd.services.xray = {
    description = "xray service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.xray}/bin/xray run -c ${config.age.secrets.xray-config.path}";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "xray";
      Group = "xray";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      StateDirectory = "xray";
      WorkingDirectory = "/var/lib/xray";
    };
  };

  # ----------------------------------------------------------------------------
  # Clash Subscription Generator
  # ----------------------------------------------------------------------------
  systemd.services.clash-generator = {
    description = "Generate Clash subscription configs from user data";
    after = [ "agenix.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = clashGenerator;
      RemainAfterExit = true;
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/clash-subscriptions 0755 root root -"
  ];

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

    # SNI-based routing: Route traffic based on TLS Server Name Indication
    # - cn.bing.com (REALITY) → xray (port 8444)
    # - Everything else → nginx HTTPS (port 8443)
    streamConfig = ''
      map $ssl_preread_server_name $backend {
        cn.bing.com 127.0.0.1:8444;
        default 127.0.0.1:8443;
      }

      server {
        listen 443;
        listen [::]:443;
        ssl_preread on;
        proxy_pass $backend;
      }
    '';

    # Default: Reject unknown hostnames
    virtualHosts."_" = {
      default = true;
      locations."/" = {
        return = "444";
      };
    };

    virtualHosts."clash.hakula.xyz" = {
      enableACME = true;
      acmeRoot = null;
      onlySSL = true;
      listen = [
        {
          addr = "127.0.0.1";
          port = 8443;
          ssl = true;
        }
      ];
      extraConfig = ''
        absolute_redirect off;
      '';
      locations."/" = {
        alias = "/var/lib/clash-subscriptions/";
        extraConfig = ''
          default_type application/x-yaml;
          add_header Content-Disposition 'attachment; filename="clash.yaml"';
          add_header Cache-Control 'no-cache, no-store, must-revalidate';
        '';
      };
      locations."= /" = {
        return = "404";
      };
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
