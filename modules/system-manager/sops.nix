# ==================================================================================================
# SOPS Secrets for System Manager
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  ...
}:

let
  cfg = config.sops;
  serviceName = "sops-install-secrets";
  secretsDir = "/run/secrets";
  managedPathsFile = "/var/lib/system-manager/sops-managed-secrets";

  secretType = lib.types.submodule (
    { config, name, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Name of the decrypted secret";
        };

        sopsFile = lib.mkOption {
          type = lib.types.path;
          description = "Encrypted SOPS file to decrypt";
        };

        format = lib.mkOption {
          type = lib.types.enum [
            "yaml"
            "json"
            "binary"
            "dotenv"
            "ini"
          ];
          default = "yaml";
          description = "SOPS input/output format for decryption";
        };

        key = lib.mkOption {
          type = lib.types.str;
          default = config.name;
          description = "Slash-separated key to extract, or empty string for whole file";
        };

        owner = lib.mkOption {
          type = lib.types.str;
          default = "root";
          description = "Owner of the decrypted secret";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = config.owner;
          description = "Group of the decrypted secret";
        };

        mode = lib.mkOption {
          type = lib.types.str;
          default = "0400";
          description = "Permissions mode for the decrypted secret";
        };

        path = lib.mkOption {
          type = lib.types.str;
          default = "${secretsDir}/${config.name}";
          description = "Path where the decrypted secret is installed";
        };
      };
    }
  );

  installSecrets = repoLib.mkNuCommand {
    inherit pkgs;
    name = serviceName;
    script = ./scripts/install-secrets.nu;
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sops
      pkgs.ssh-to-age
    ];
    config = {
      inherit secretsDir managedPathsFile;
      identityPaths = cfg.age.sshKeyPaths;
      secrets = map (secret: {
        inherit (secret)
          name
          format
          key
          owner
          group
          mode
          path
          ;
        sopsFile = "${secret.sopsFile}";
      }) (lib.attrValues cfg.secrets);
    };
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.sops = {
    age.sshKeyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Private SSH ed25519 key paths converted to age identities for decryption";
    };

    secrets = lib.mkOption {
      type = lib.types.attrsOf secretType;
      default = { };
      description = "SOPS-encrypted secrets to decrypt during activation";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf (cfg.secrets != { }) {
    assertions = [
      {
        assertion = cfg.age.sshKeyPaths != [ ];
        message = "sops.age.sshKeyPaths must include at least one decryption key.";
      }
    ];

    systemd.services.${serviceName} = {
      description = "Install SOPS secrets";
      wantedBy = [
        "system-manager.target"
      ];
      before = [
        "system-manager.target"
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe installSecrets;
      };
    };
  };
}
