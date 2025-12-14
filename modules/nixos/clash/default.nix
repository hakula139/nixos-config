{ realitySniHost }:
{
  config,
  pkgs,
  ...
}:

# ==============================================================================
# Clash Subscription Generator (Service)
# ==============================================================================

let
  clashGenerator = import ./generator { inherit config pkgs realitySniHost; };
in
{
  # ----------------------------------------------------------------------------
  # User & Group
  # ----------------------------------------------------------------------------
  users.users.clashgen = {
    isSystemUser = true;
    group = "clashgen";
  };
  users.groups.clashgen = { };

  # ----------------------------------------------------------------------------
  # Secrets (agenix)
  # ----------------------------------------------------------------------------
  age.secrets.clash-users = {
    file = ../../../secrets/clash-users.json.age;
    owner = "clashgen";
    group = "clashgen";
    mode = "0400";
  };

  # ----------------------------------------------------------------------------
  # Systemd service
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
}
