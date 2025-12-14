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
  cfg = config.services.cloudconeAgent;
  cloudconeAgent = import ./agent { inherit config pkgs; };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.services.cloudconeAgent = {
    enable = lib.mkEnableOption "CloudCone monitoring agent";

    serverKeyFile = lib.mkOption {
      type = lib.types.str;
      default = config.age.secrets.cloudcone-sc2-server-key.path;
    };

    intervalSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
    };
  };

  config = lib.mkIf cfg.enable {
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
    age.secrets.cloudcone-sc2-server-key = {
      file = ../../../secrets/cloudcone-sc2/server-key.age;
      owner = "ccagent";
      group = "ccagent";
      mode = "0400";
    };

    # ----------------------------------------------------------------------------
    # Filesystem layout
    # ----------------------------------------------------------------------------
    systemd.tmpfiles.rules = [
      "d /opt/cloudcone 0700 ccagent ccagent -"
    ];

    # ----------------------------------------------------------------------------
    # Systemd service
    # ----------------------------------------------------------------------------
    systemd.services.cloudcone-agent = {
      description = "CloudCone monitoring agent";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
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
        WorkingDirectory = "/opt/cloudcone";
      };
      serviceConfig.ExecStart = "${cloudconeAgent}/bin/cloudcone-agent";
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
  };
}
