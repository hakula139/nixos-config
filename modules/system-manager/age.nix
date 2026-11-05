# ==================================================================================================
# Age Secrets for System Manager
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  esc = lib.escapeShellArg;

  cfg = config.age;
  identityPathArgs = lib.escapeShellArgs cfg.identityPaths;
  serviceName = "agenix-install-secrets";
  secretsDir = "/run/agenix";
  ageBin = lib.getExe pkgs.age;
  managedPathsFile = "/var/lib/system-manager/agenix-managed-secrets";

  secretType = lib.types.submodule (
    { config, name, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Name of the decrypted secret";
        };

        file = lib.mkOption {
          type = lib.types.path;
          description = "Encrypted age file to decrypt";
        };

        owner = lib.mkOption {
          type = lib.types.str;
          default = "root";
          description = "Owner of the decrypted secret";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "root";
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

  decryptSecret = secret: ''
    target=${esc secret.path}
    tmp="$target.tmp"

    echo "decrypting" ${esc secret.name} "to $target"
    target_dir="$(dirname "$target")"
    if [[ ! -d "$target_dir" ]]; then
      install -dm0700 \
        -o ${esc secret.owner} \
        -g ${esc secret.group} \
        "$target_dir"
    fi
    rm -f "$tmp"

    ${ageBin} --decrypt "''${identityArgs[@]}" -o "$tmp" ${esc "${secret.file}"}
    chmod ${esc secret.mode} "$tmp"
    chown ${esc "${secret.owner}:${secret.group}"} "$tmp"
    mv -f "$tmp" "$target"
  '';

  secretTargets = map (secret: secret.path) (lib.attrValues cfg.secrets);
  desiredManifest = pkgs.writeText "agenix-managed-secrets" (
    lib.concatStringsSep "\n" secretTargets + "\n"
  );
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.age = {
    identityPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Private SSH or age identity paths used for decryption";
    };

    secrets = lib.mkOption {
      type = lib.types.attrsOf secretType;
      default = { };
      description = "age-encrypted secrets to decrypt during activation";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf (cfg.secrets != { }) {
    assertions = [
      {
        assertion = cfg.identityPaths != [ ];
        message = "age.identityPaths must include at least one decryption identity.";
      }
    ];

    systemd.services.${serviceName} = {
      description = "Install age secrets";
      wantedBy = [
        "system-manager.target"
      ];
      before = [
        "system-manager.target"
      ];

      path = [
        pkgs.coreutils
        pkgs.gnugrep
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail

        identityArgs=()
        for identity in ${identityPathArgs}; do
          if [[ -r "$identity" && -s "$identity" ]]; then
            identityArgs+=(-i "$identity")
          else
            echo "warning: age identity not readable: $identity" >&2
          fi
        done

        if [[ "''${#identityArgs[@]}" -eq 0 ]]; then
          echo "error: no readable age identities found in:" ${identityPathArgs} >&2
          exit 1
        fi

        ${lib.concatStringsSep "\n" (map decryptSecret (lib.attrValues cfg.secrets))}

        manifest=${esc managedPathsFile}
        desired=${desiredManifest}

        if [[ -f "$manifest" ]]; then
          while IFS= read -r managed_path; do
            if [[ -n "$managed_path" ]] && ! grep -Fx -- "$managed_path" "$desired" >/dev/null; then
              rm -f -- "$managed_path"
            fi
          done <"$manifest"
        fi

        install -dm0755 "$(dirname "$manifest")"
        install -m0644 "$desired" "$manifest"
      '';
    };
  };
}
