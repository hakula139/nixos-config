# ==================================================================================================
# Xray (VLESS + REALITY / WebSocket)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  hostName,
  repoLib,
  servers,
  ...
}:

let
  cfg = config.hakula.services.xray;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.services.xray = {
    enable = lib.mkEnableOption "Xray proxy server";

    ws.enable = lib.mkEnableOption "VLESS + WebSocket mode";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      json = pkgs.formats.json { };

      configFile = "/run/xray-config/config.json";

      # Clients, short IDs, and the private key are filled in at runtime from the secrets.
      renderConfig = json.generate "xray-render.json" {
        settings = {
          log = {
            loglevel = "warning";
            access = "none";
          };

          inbounds = [
            {
              tag = "vless-reality";
              # The suffix is Xray's octal socket mode, applied with chmod after bind.
              listen = "${config.hakula.network.internalRealitySocket},0666";
              protocol = "vless";

              settings.decryption = "none";

              streamSettings = {
                network = "tcp";
                tcpSettings.acceptProxyProtocol = true;
                security = "reality";

                realitySettings = {
                  dest = config.hakula.network.internalHttpsSocket;
                  # nginx's listener requires a PROXY header, so omitting it breaks the fallback.
                  xver = 1;
                  serverNames = [ config.hakula.network.realitySniHost ];
                };
              };
            }
          ]
          ++ lib.optional cfg.ws.enable {
            tag = "vless-ws";
            listen = "${config.hakula.network.internalWsSocket},0666";
            protocol = "vless";

            settings.decryption = "none";

            streamSettings = {
              network = "ws";
              wsSettings.path = "/ws";
            };
          };

          outbounds = [
            { protocol = "freedom"; }
          ];
        };

        clientFlows.vless-reality = "xtls-rprx-vision";
        minLevel = servers.${hostName}.proxyLevel;

        usersFile = config.age.secrets.xray-users.path;
        privateKeyFile = config.age.secrets.xray-reality-private-key.path;
        outputFile = configFile;
      };

      renderScript = pkgs.writers.writeNu "xray-render-config" {
        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath [ pkgs.coreutils ])

          "--add-flag"
          "${renderConfig}"
        ];
      } (builtins.readFile ./render-config.nu);
    in
    {
      # --------------------------------------------------------------------------------------------
      # Secrets
      # --------------------------------------------------------------------------------------------
      age.secrets.xray-users = repoLib.secrets.mkSecret {
        name = "xray/users.json";
      };

      age.secrets.xray-reality-private-key = repoLib.secrets.mkSecret {
        name = "xray/reality-private-key";
      };

      # --------------------------------------------------------------------------------------------
      # Xray service
      # --------------------------------------------------------------------------------------------
      services.xray = {
        enable = true;
        settingsFile = configFile;
      };

      # The nixpkgs wrapper keeps `.xray-wrapped` as its comm.
      hakula.services.earlyoom.ignoreComms = [
        "[.]xray-wrapped"
      ];

      # --------------------------------------------------------------------------------------------
      # Systemd service
      # --------------------------------------------------------------------------------------------
      systemd.services.xray = lib.mkMerge [
        repoLib.systemd.restartUnit

        {
          serviceConfig = {
            # Inbounds are Unix sockets, and CAP_NET_ADMIN could route around the deny list.
            AmbientCapabilities = lib.mkForce "";
            CapabilityBoundingSet = lib.mkForce "";

            # Ensures resolution survives an nscd outage.
            Environment = "LD_LIBRARY_PATH=${config.system.nssModules.path}";

            IPAddressDeny = [
              "link-local"
              "multicast"
              "0.0.0.0/8"
              "10.0.0.0/8"
              "100.64.0.0/10"
              "172.16.0.0/12"
              "192.0.0.0/24"
              "192.0.2.0/24"
              "192.168.0.0/16"
              "198.18.0.0/15"
              "198.51.100.0/24"
              "203.0.113.0/24"
              "240.0.0.0/4"
              "64:ff9b:1::/48"
              "100::/64"
              "100:0:0:1::/64"
              "2001:2::/48"
              "2001:db8::/32"
              "3fff::/20"
              "5f00::/16"
              "fc00::/7"
              "fe80::/10"
            ];

            # Traffic to any address the host owns, RA-assigned ones included, is delivered over lo.
            RestrictNetworkInterfaces = "~lo";

            # nginx runs as its own user and must traverse this directory to reach the sockets.
            RuntimeDirectory = "xray";
            RuntimeDirectoryMode = "0755";
          };
        }
      ];

      # `requiredBy` also propagates restarts, so Xray reloads whenever the config is re-rendered.
      systemd.services.xray-config = {
        description = "Render Xray config from proxy users";
        after = [
          "agenix.service"
        ];
        before = [
          "xray.service"
        ];
        requiredBy = [
          "xray.service"
        ];

        serviceConfig = repoLib.systemd.hardening // {
          Type = "oneshot";
          ExecStart = renderScript;
          RemainAfterExit = true;
          RuntimeDirectory = "xray-config";
          RuntimeDirectoryMode = "0700";
        };

        restartTriggers = [
          config.age.secrets.xray-users.file
          config.age.secrets.xray-reality-private-key.file
        ];
      };
    }
  );
}
