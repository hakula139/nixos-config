{
  config,
  lib,
  pkgs,
  inputs,
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
  cloudflareOriginCA = ./cloudflare-origin-pull-ca.pem;

  # REALITY SNI Host
  # If you change this, also update secrets/xray-config.json.age.
  realitySniHost = "www.microsoft.com";
  clashGenerator = import ./clash-generator { inherit config pkgs realitySniHost; };

  netdataPkgsUnstable = import inputs.nixpkgs-unstable {
    system = pkgs.system;
    config = config.nixpkgs.config;
  };
  netdataPkgUnstable = netdataPkgsUnstable.netdata.override { withCloudUi = true; };
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

  users.users.xray = {
    isSystemUser = true;
    group = "xray";
  };
  users.groups.xray = { };

  users.users.clashgen = {
    isSystemUser = true;
    group = "clashgen";
  };
  users.groups.clashgen = { };

  users.users.acme = {
    isSystemUser = true;
    group = "acme";
  };
  users.groups.acme = { };

  users.users.nginx = {
    isSystemUser = true;
    group = "nginx";
    extraGroups = [
      "acme"
      "clashgen"
    ];
  };
  users.groups.nginx = { };

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

  age.secrets.xray-config = {
    file = ../../secrets/xray-config.json.age;
    owner = "xray";
    group = "xray";
    mode = "0400";
  };

  age.secrets.clash-users = {
    file = ../../secrets/clash-users.json.age;
    owner = "clashgen";
    group = "clashgen";
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

  # ----------------------------------------------------------------------------
  # Proxy (Xray with VLESS + REALITY)
  # ----------------------------------------------------------------------------
  systemd.services.xray = {
    description = "xray service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.xray}/bin/xray run -format json -c ${config.age.secrets.xray-config.path}";
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
      User = "clashgen";
      Group = "clashgen";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      StateDirectory = "clash-subscriptions";
      StateDirectoryMode = "0750";
      WorkingDirectory = "/var/lib/clash-subscriptions";
    };
  };

  # ----------------------------------------------------------------------------
  # Netdata (System Monitoring)
  # ----------------------------------------------------------------------------
  services.netdata = {
    enable = true;
    package = netdataPkgUnstable;
    config = {
      global = {
        "hostname" = "cloudcone-sc2";
      };
      directories = {
        "web files directory" = "${netdataPkgUnstable}/share/netdata/web";
      };
      db = {
        "update every" = 2;
        "mode" = "dbengine";
        "storage tiers" = 2;
        "dbengine page cache size MB" = 32;
        "dbengine disk space MB" = 768;
        "dbengine tier 1 update every iterations" = 60;
        "dbengine tier 1 page cache size MB" = 16;
        "dbengine tier 1 disk space MB" = 256;
      };
      web = {
        "bind to" = "127.0.0.1:19999";
        "enable gzip compression" = "yes";
      };
    };
  };

  systemd.services.netdata =
    let
      systemdCatNative = pkgs.writeShellScriptBin "systemd-cat-native" ''
        tag=""
        out=()
        for arg in "$@"; do
          if [ "$arg" = "--log-as-netdata" ]; then
            tag="netdata"
          else
            out+=("$arg")
          fi
        done

        if [ -n "$tag" ]; then
          exec ${pkgs.systemd}/bin/systemd-cat -t "$tag" "''${out[@]}"
        else
          exec ${pkgs.systemd}/bin/systemd-cat "''${out[@]}"
        fi
      '';
    in
    {
      path = [
        pkgs.systemd
        systemdCatNative
      ];
      environment.NETDATA_PREFIX = "${netdataPkgUnstable}";
    };

  # ----------------------------------------------------------------------------
  # Web Server (nginx + ACME)
  # ----------------------------------------------------------------------------
  services.nginx = {
    enable = true;
    user = "nginx";
    group = "nginx";
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
    # - REALITY → Xray (port 8444)
    # - Everything else → nginx HTTPS (port 8443)
    streamConfig = ''
      map $ssl_preread_server_name $backend {
        ${realitySniHost} 127.0.0.1:8444;
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
      useACMEHost = "hakula.xyz";
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
        ssl_client_certificate ${cloudflareOriginCA};
        ssl_verify_client on;
        ssl_stapling off;
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

    virtualHosts."metrics-us.hakula.xyz" = {
      useACMEHost = "hakula.xyz";
      onlySSL = true;
      listen = [
        {
          addr = "127.0.0.1";
          port = 8443;
          ssl = true;
        }
      ];
      extraConfig = ''
        ssl_client_certificate ${cloudflareOriginCA};
        ssl_verify_client on;
        ssl_stapling off;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:19999/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffering off;
          proxy_request_buffering off;
        '';
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
    certs."hakula.xyz" = {
      domain = "*.hakula.xyz";
      extraDomainNames = [ "hakula.xyz" ];
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
