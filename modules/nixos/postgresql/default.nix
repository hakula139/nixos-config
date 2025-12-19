{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# PostgreSQL (Database Server)
# ==============================================================================

let
  cfg = config.hakula.services.postgresql;
in
{
  options.hakula.services.postgresql = {
    enable = lib.mkEnableOption "PostgreSQL database server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.postgresql_17;
      description = "PostgreSQL package / version to use for this host";
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      package = cfg.package;
    };
  };
}
