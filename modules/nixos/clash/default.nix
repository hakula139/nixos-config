{
  config,
  pkgs,
  lib,
  secrets,
  realitySniHost,
  ...
}:

# ==============================================================================
# Clash Subscription Generator (Service)
# ==============================================================================

let
  cfg = config.hakula.services.clashGenerator;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.services.clashGenerator = {
    enable = lib.mkEnableOption "Clash subscription generator service";
  };

  config = lib.mkIf cfg.enable (
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
      # Secrets
      # ----------------------------------------------------------------------------
      age.secrets.clash-users = secrets.mkSecret {
        name = "clash-users.json";
        owner = "clashgen";
        group = "clashgen";
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
          ProtectControlGroups = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          StateDirectory = "%N";
          StateDirectoryMode = "0750";
          WorkingDirectory = "%S/%N";
        };
        restartTriggers = [ config.age.secrets.clash-users.file ];
      };
    }
  );
}
