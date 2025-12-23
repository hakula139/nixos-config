{ lib }:

# ==============================================================================
# Backup Target Module
# ==============================================================================

lib.types.submodule (
  { name, ... }:
  {
    options = {
      enable = lib.mkEnableOption "this backup target";

      schedule = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "*-*-* 04:00:00";
        description = "Override the default schedule for this target";
      };

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Paths to backup for this target";
      };

      extraBackupArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra arguments to pass to restic backup";
      };

      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra groups for the backup user (for accessing target resources)";
      };

      runtimeInputs = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Extra packages available during prepareCommand";
      };

      prepareCommand = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Command to run before backup (e.g., export data)";
      };

      cleanupCommand = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Command to run after backup (e.g., cleanup temp files)";
      };

      restoreCommand = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Command to run after restore (e.g., import data)";
      };

      restoreSnapshot = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        example = "latest";
        description = "Snapshot ID to restore from (e.g., 'latest', or a specific snapshot ID)";
      };
    };
  }
)
