# ==================================================================================================
# Clash Subscription Generator (Service)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  servers,
  ...
}:

let
  cfg = config.hakula.services.clashGenerator;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.services.clashGenerator = {
    enable = lib.mkEnableOption "Clash subscription generator service";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      clashGenerator = import ./generator {
        inherit
          config
          pkgs
          lib
          repoLib
          servers
          ;
      };
    in
    {
      # --------------------------------------------------------------------------------------------
      # User & Group
      # --------------------------------------------------------------------------------------------
      users.users.clashgen = {
        isSystemUser = true;
        group = "clashgen";
      };

      users.groups.clashgen = { };

      # --------------------------------------------------------------------------------------------
      # Secrets
      # --------------------------------------------------------------------------------------------
      sops.secrets.clash-users = repoLib.secrets.mkSecret {
        name = "xray/users.json";
        owner = "clashgen";
        group = "clashgen";
        restartUnits = [ "clash-generator.service" ];
      };

      # --------------------------------------------------------------------------------------------
      # Systemd service
      # --------------------------------------------------------------------------------------------
      systemd.services.clash-generator = {
        description = "Generate Clash subscription configs from user data";
        wantedBy = [
          "multi-user.target"
        ];
        serviceConfig = repoLib.systemd.hardening // {
          Type = "oneshot";
          ExecStart = lib.getExe clashGenerator;
          RemainAfterExit = true;
          User = "clashgen";
          Group = "clashgen";
          StateDirectory = "%N";
          StateDirectoryMode = "0750";
          WorkingDirectory = "%S/%N";
        };
      };
    }
  );
}
