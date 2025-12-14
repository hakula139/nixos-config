{
  config,
  pkgs,
  ...
}:

# ============================================================================
# Xray (VLESS + REALITY)
# ============================================================================

{
  # ----------------------------------------------------------------------------
  # User & Group
  # ----------------------------------------------------------------------------
  users.users.xray = {
    isSystemUser = true;
    group = "xray";
  };
  users.groups.xray = { };

  # ----------------------------------------------------------------------------
  # Secrets (agenix)
  # ----------------------------------------------------------------------------
  age.secrets.xray-config = {
    file = ../../../secrets/xray-config.json.age;
    owner = "xray";
    group = "xray";
    mode = "0400";
  };

  # ----------------------------------------------------------------------------
  # systemd service
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
}
