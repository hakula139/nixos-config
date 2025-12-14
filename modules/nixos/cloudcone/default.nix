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

  # Pinned upstream agent script
  agentScript = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Cloudcone/cloud-view/master/agent.sh";
    hash = "sha256-VTKxN2yykeNANqE5vF7rpsscDPr7CKykiggpTY8qRQQ=";
  };
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

    gatewayUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://watch.cloudc.one/agent";
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
      home = "/opt/cloudcone";
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
      "L+ /opt/cloudcone/agent.sh - - - - ${agentScript}"
      "w /opt/cloudcone/gateway 0600 ccagent ccagent - ${cfg.gatewayUrl}"
      "L+ /opt/cloudcone/serverkey - - - - ${cfg.serverKeyFile}"
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
      path = with pkgs; [
        bash
        curl
        coreutils
        gawk
        gnugrep
        gnused
        iproute2
        iputils
        procps
        util-linux
      ];
      script = ''
        exec bash /opt/cloudcone/agent.sh
      '';
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
