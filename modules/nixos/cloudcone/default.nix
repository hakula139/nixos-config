{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# CloudCone Agent (Monitoring)
# ==============================================================================

let
  cfg = config.hakula.services.cloudconeAgent;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.cloudconeAgent = {
    enable = lib.mkEnableOption "CloudCone monitoring agent";

    serverKeyAgeFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the CloudCone server key file";
    };

    intervalSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Interval in seconds between CloudCone agent runs";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      secretName = "cloudcone-server-key";
      cloudconeAgent = import ./agent {
        inherit pkgs;
        serverKeyFile = config.age.secrets.${secretName}.path;
      };
    in
    {
      assertions = [
        {
          assertion = cfg.serverKeyAgeFile != null;
          message = "hakula.services.cloudconeAgent.serverKeyAgeFile must be set.";
        }
      ];

      # ----------------------------------------------------------------------------
      # User & Group
      # ----------------------------------------------------------------------------
      users.users.ccagent = {
        isSystemUser = true;
        group = "ccagent";
      };
      users.groups.ccagent = { };

      # ----------------------------------------------------------------------------
      # Secrets (agenix)
      # ----------------------------------------------------------------------------
      age.secrets.${secretName} = {
        file = cfg.serverKeyAgeFile;
        owner = "ccagent";
        group = "ccagent";
        mode = "0400";
      };

      # ----------------------------------------------------------------------------
      # Systemd service
      # ----------------------------------------------------------------------------
      systemd.services.cloudcone-agent = {
        description = "CloudCone monitoring agent";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${cloudconeAgent}/bin/cloudcone-agent";
          User = "ccagent";
          Group = "ccagent";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ProtectControlGroups = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          AmbientCapabilities = [ "CAP_NET_RAW" ];
          CapabilityBoundingSet = [ "CAP_NET_RAW" ];
          StateDirectory = "%N";
          StateDirectoryMode = "0700";
          WorkingDirectory = "%S/%N";
        };
      };

      # ----------------------------------------------------------------------------
      # Systemd timer
      # ----------------------------------------------------------------------------
      systemd.timers.cloudcone-agent = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          Unit = "cloudcone-agent.service";
          OnBootSec = "2m";
          OnUnitActiveSec = "${toString cfg.intervalSeconds}s";
          AccuracySec = "30s";
          RandomizedDelaySec = "10s";
        };
      };
    }
  );
}
