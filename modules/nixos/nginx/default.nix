{ realitySniHost }:
{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Nginx (Web Server)
# ==============================================================================

let
  cfg = config.hakula.services.nginx;

  # ----------------------------------------------------------------------------
  # Cloudflare
  # ----------------------------------------------------------------------------
  cloudflareIPs = import ../cloudflare/ips.nix;
  cloudflareRealIPConfig = lib.concatMapStringsSep "\n" (ip: "set_real_ip_from ${ip};") (
    cloudflareIPs.ipv4 ++ cloudflareIPs.ipv6
  );
  cloudflareOriginCA = ../cloudflare/origin-pull-ca.pem;

  # ----------------------------------------------------------------------------
  # Upstreams
  # ----------------------------------------------------------------------------
  cloudreveUpstream = "http://127.0.0.1:${toString config.hakula.services.cloudreve.port}";
  cloudreveNoBufferingExtra = ''
    proxy_buffering off;
    proxy_request_buffering off;
    proxy_max_temp_file_size 0;
  '';

  piclistUpstream = "http://127.0.0.1:${toString config.hakula.services.piclist.port}";

  # ----------------------------------------------------------------------------
  # Shared Configuration
  # ----------------------------------------------------------------------------
  sharedVhostConfig = {
    useACMEHost = "hakula.xyz";
    onlySSL = true;
    http2 = true;
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
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.nginx = {
    enable = lib.mkEnableOption "Nginx web server";
  };

  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------
    # Users & Groups
    # ----------------------------------------------------------------------------
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

    # ----------------------------------------------------------------------------
    # Secrets (agenix)
    # ----------------------------------------------------------------------------
    age.secrets.cloudflare-credentials = {
      file = ../../../secrets/shared/cloudflare-credentials.age;
      owner = "acme";
      group = "acme";
      mode = "0400";
    };

    # ----------------------------------------------------------------------------
    # ACME (Let's Encrypt)
    # ----------------------------------------------------------------------------
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

    # ----------------------------------------------------------------------------
    # Nginx service
    # ----------------------------------------------------------------------------
    services.nginx = {
      enable = true;
      user = "nginx";
      group = "nginx";
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      clientMaxBodySize = "500M";

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
          error_log /var/log/nginx/stream-error.log crit;
          ssl_preread on;
          proxy_pass $backend;
        }
      '';

      # --------------------------------------------------------------------------
      # Virtual hosts
      # --------------------------------------------------------------------------
      # Default: Proxy to REALITY host (anti-fingerprint)
      virtualHosts."_" = {
        default = true;
        locations."/" = {
          proxyPass = "https://${realitySniHost}";
          extraConfig = ''
            proxy_ssl_server_name on;
            proxy_ssl_name ${realitySniHost};
          '';
        };
      };

      # Clash subscriptions
      virtualHosts."clash.hakula.xyz" = sharedVhostConfig // {
        extraConfig = sharedVhostConfig.extraConfig + ''
          absolute_redirect off;
        '';
        locations."/" = {
          alias = "/var/lib/clash-generator/";
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

      # Cloudreve cloud storage
      virtualHosts."cloud.hakula.xyz" = sharedVhostConfig // {
        extraConfig = sharedVhostConfig.extraConfig + ''
          client_body_timeout 300s;
          client_header_timeout 60s;

          proxy_connect_timeout 60s;
          proxy_send_timeout 600s;
          proxy_read_timeout 600s;
        '';
        locations."/api/v4/ws" = {
          proxyPass = cloudreveUpstream;
          proxyWebsockets = true;
        };
        locations."/api/v4/file/download" = {
          proxyPass = cloudreveUpstream;
          extraConfig = cloudreveNoBufferingExtra;
        };
        locations."/api/v4/file/upload" = {
          proxyPass = cloudreveUpstream;
          extraConfig = cloudreveNoBufferingExtra;
        };
        locations."/dav" = {
          proxyPass = "${cloudreveUpstream}/dav";
          extraConfig = cloudreveNoBufferingExtra;
        };
        locations."/" = {
          proxyPass = "${cloudreveUpstream}/";
        };
      };

      # Netdata dashboard
      virtualHosts."metrics-${config.networking.hostName}.hakula.xyz" = sharedVhostConfig // {
        locations."/" = {
          proxyPass = "http://127.0.0.1:19999/";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
          '';
        };
      };

      # PicList image upload server
      virtualHosts."static.hakula.xyz" = lib.mkIf config.hakula.services.piclist.enable (
        sharedVhostConfig
        // {
          locations."/upload" = {
            proxyPass = "${piclistUpstream}/upload";
            extraConfig = ''
              proxy_buffering off;
              proxy_request_buffering off;
            '';
          };
          locations."/" = {
            return = "302 https://cloud.hakula.xyz";
          };
        }
      );

      # Xray WebSocket proxy (with Cloudflare CDN)
      # Note: We use WebSocket instead of gRPC to avoid Cloudflare's DDoS protection false positives.
      virtualHosts."${config.networking.hostName}-cdn.hakula.xyz" =
        lib.mkIf config.hakula.services.xray.ws.enable
          (
            sharedVhostConfig
            // {
              http2 = false;
              locations."/ws" = {
                proxyPass = "http://127.0.0.1:${toString config.hakula.services.xray.ws.port}";
                proxyWebsockets = true;
                extraConfig = ''
                  proxy_redirect off;
                  proxy_connect_timeout 60s;
                  proxy_send_timeout 60s;
                  proxy_read_timeout 300s;
                '';
              };
              # Redirect all other requests to main site
              locations."/" = {
                return = "302 https://hakula.xyz";
              };
            }
          );
    };
  };
}
