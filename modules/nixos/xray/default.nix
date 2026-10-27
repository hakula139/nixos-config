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

    reality.port = lib.mkOption {
      type = lib.types.port;
      default = 8444;
      description = "Port for Xray REALITY inbound";
    };

    ws = {
      enable = lib.mkEnableOption "VLESS + WebSocket mode";

      port = lib.mkOption {
        type = lib.types.port;
        default = 8445;
        description = "Port for Xray WebSocket inbound";
      };
    };
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
          log.loglevel = "warning";

          inbounds = [
            {
              tag = "vless-reality";
              listen = "127.0.0.1";
              inherit (cfg.reality) port;
              protocol = "vless";

              settings.decryption = "none";

              streamSettings = {
                network = "tcp";
                security = "reality";

                realitySettings = {
                  dest = "127.0.0.1:8443";
                  serverNames = [ config.hakula.network.realitySniHost ];
                };
              };
            }
          ]
          ++ lib.optional cfg.ws.enable {
            tag = "vless-ws";
            listen = "127.0.0.1";
            inherit (cfg.ws) port;
            protocol = "vless";

            settings.decryption = "none";

            streamSettings = {
              network = "ws";
              wsSettings.path = "/ws";
            };
          };

          outbounds = [ { protocol = "freedom"; } ];
        };

        clientFlows.vless-reality = "xtls-rprx-vision";
        minLevel = servers.${hostName}.proxyLevel;

        usersFile = config.age.secrets.xray-users.path;
        privateKeyFile = config.age.secrets.xray-reality-private-key.path;
        outputFile = configFile;
      };

      renderScript = pkgs.writers.writeNu "xray-render-config" {
        makeWrapperArgs = [
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
      hakula.services.earlyoom.ignoreComms = [ "[.]xray-wrapped" ];

      # --------------------------------------------------------------------------------------------
      # Systemd service
      # --------------------------------------------------------------------------------------------
      systemd.services.xray = repoLib.systemd.restartUnit;

      # `requiredBy` also propagates restarts, so Xray reloads whenever the config is re-rendered.
      systemd.services.xray-config = {
        description = "Render Xray config from proxy users";
        after = [ "agenix.service" ];
        before = [ "xray.service" ];
        requiredBy = [ "xray.service" ];

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
