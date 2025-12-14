{ realitySniHost }:
{
  config,
  pkgs,
  lib,
  ...
}:

# ============================================================================
# Nginx (Web Server)
# ============================================================================

let
  cloudflareIPs = import ../cloudflare/ips.nix;
  cloudflareRealIPConfig = lib.concatMapStringsSep "\n" (ip: "set_real_ip_from ${ip};") (
    cloudflareIPs.ipv4 ++ cloudflareIPs.ipv6
  );
  cloudflareOriginCA = ../cloudflare/origin-pull-ca.pem;
in
{
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

  services.nginx = {
    enable = true;
    user = "nginx";
    group = "nginx";
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    clientMaxBodySize = "10G";

    # Cloudflare real IP detection
    commonHttpConfig = ''
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

    # Clash subscriptions
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

    # Netdata dashboard
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
}
