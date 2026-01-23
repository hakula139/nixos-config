{ realitySniHost }:
{
  config,
  pkgs,
  lib,
  secrets,
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
  fuclaudeUpstream = "http://127.0.0.1:${toString config.hakula.services.fuclaude.port}";
  piclistUpstream = "http://127.0.0.1:${toString config.hakula.services.piclist.port}";
  umamiUpstream = "http://127.0.0.1:${toString config.hakula.services.umami.port}";

  # ----------------------------------------------------------------------------
  # Shared Configuration
  # ----------------------------------------------------------------------------
  baseVhostConfig = {
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
      ssl_stapling off;
    '';
  };

  cloudflareVhostConfig = baseVhostConfig // {
    extraConfig = baseVhostConfig.extraConfig + ''
      ssl_client_certificate ${cloudflareOriginCA};
      ssl_verify_client on;
    '';
  };

  noBufferingExtraConfig = ''
    proxy_buffering off;
    proxy_request_buffering off;
    proxy_max_temp_file_size 0;
  '';

  noCacheExtraConfig = ''
    add_header Cache-Control 'no-cache, no-store, must-revalidate' always;
    add_header Pragma 'no-cache' always;
    add_header Expires '0' always;
  '';
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
      ]
      ++ lib.optional config.hakula.services.clashGenerator.enable "clashgen";
    };
    users.groups.nginx = { };

    # ----------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------
    age.secrets.cloudflare-credentials = secrets.mkSecret {
      name = "cloudflare-credentials";
      owner = "acme";
      group = "acme";
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
          ${lib.optionalString config.networking.enableIPv6 "listen [::]:443;"}
          error_log /var/log/nginx/stream-error.log crit;
          ssl_preread on;
          proxy_pass $backend;
        }
      '';

      # --------------------------------------------------------------------------
      # Virtual hosts
      # --------------------------------------------------------------------------
      # Default: Proxy to REALITY host (anti-fingerprint)
      virtualHosts."_" = baseVhostConfig // {
        default = true;
        locations."/" = {
          proxyPass = "https://$reality_upstream";
          extraConfig = ''
            set $reality_upstream ${realitySniHost};
            proxy_ssl_server_name on;
            proxy_ssl_name ${realitySniHost};
            proxy_set_header Host ${realitySniHost};
            resolver 8.8.8.8 1.1.1.1;
          '';
        };
      };

      # Clash subscriptions
      virtualHosts."clash.hakula.xyz" = lib.mkIf config.hakula.services.clashGenerator.enable (
        cloudflareVhostConfig
        // {
          extraConfig = cloudflareVhostConfig.extraConfig + ''
            absolute_redirect off;
          '';
          locations."/" = {
            alias = "/var/lib/clash-generator/";
            extraConfig = ''
              default_type application/x-yaml;
              add_header Content-Disposition 'attachment; filename="clash.yaml"';
              ${noCacheExtraConfig}
            '';
          };
          locations."= /" = {
            return = "404";
          };
        }
      );

      # Fuclaude (Claude mirror)
      virtualHosts."claude.hakula.xyz" = lib.mkIf config.hakula.services.fuclaude.enable (
        cloudflareVhostConfig
        // {
          locations."/" = {
            proxyPass = "${fuclaudeUpstream}/";
            proxyWebsockets = true;
            extraConfig = noBufferingExtraConfig;
          };
        }
      );

      # Cloudreve cloud storage
      virtualHosts."cloud.hakula.xyz" = lib.mkIf config.hakula.services.cloudreve.enable (
        cloudflareVhostConfig
        // {
          extraConfig = cloudflareVhostConfig.extraConfig + ''
            client_body_timeout 300s;
            client_header_timeout 60s;
            proxy_connect_timeout 60s;
            proxy_send_timeout 600s;
            proxy_read_timeout 600s;
          '';
          locations."= /index.html" = {
            proxyPass = "${cloudreveUpstream}/index.html";
            extraConfig = noCacheExtraConfig;
          };
          locations."= /sw.js" = {
            proxyPass = "${cloudreveUpstream}/sw.js";
            extraConfig = noCacheExtraConfig;
          };
          locations."= /manifest.json" = {
            proxyPass = "${cloudreveUpstream}/manifest.json";
            extraConfig = noCacheExtraConfig;
          };
          locations."/api/v4/ws" = {
            proxyPass = cloudreveUpstream;
            proxyWebsockets = true;
          };
          locations."/api/v4/file/download" = {
            proxyPass = cloudreveUpstream;
            extraConfig = noBufferingExtraConfig;
          };
          locations."/api/v4/file/upload" = {
            proxyPass = cloudreveUpstream;
            extraConfig = noBufferingExtraConfig;
          };
          locations."/dav" = {
            proxyPass = "${cloudreveUpstream}/dav";
            extraConfig = noBufferingExtraConfig;
          };
          locations."/" = {
            proxyPass = "${cloudreveUpstream}/";
          };
        }
      );

      # Netdata dashboard
      virtualHosts."metrics-${config.networking.hostName}.hakula.xyz" =
        lib.mkIf config.hakula.services.netdata.enable
          (
            cloudflareVhostConfig
            // {
              locations."/" = {
                proxyPass = "http://127.0.0.1:19999/";
                proxyWebsockets = true;
                extraConfig = noBufferingExtraConfig;
              };
            }
          );

      # PicList image upload server
      virtualHosts."static.hakula.xyz" = lib.mkIf config.hakula.services.piclist.enable (
        cloudflareVhostConfig
        // {
          locations."/upload" = {
            proxyPass = "${piclistUpstream}/upload";
            extraConfig = noBufferingExtraConfig;
          };
          locations."/" = {
            return = "302 https://cloud.hakula.xyz";
          };
        }
      );

      # Umami analytics
      virtualHosts."umami.hakula.xyz" = lib.mkIf config.hakula.services.umami.enable (
        cloudflareVhostConfig
        // {
          locations."/" = {
            proxyPass = "${umamiUpstream}/";
          };
        }
      );

      # Xray WebSocket proxy (with Cloudflare CDN)
      # Note: We use WebSocket instead of gRPC to avoid Cloudflare's DDoS protection false positives.
      virtualHosts."${config.networking.hostName}-cdn.hakula.xyz" =
        lib.mkIf config.hakula.services.xray.ws.enable
          (
            cloudflareVhostConfig
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
