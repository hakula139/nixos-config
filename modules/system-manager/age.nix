# ==============================================================================
# Age Secrets for System Manager
# ==============================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.age;
  serviceName = "agenix-install-secrets";
  secretsDir = "/run/agenix";

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

        path = lib.mkOption {
          type = lib.types.str;
          default = "${secretsDir}/${config.name}";
          description = "Path where the decrypted secret is installed";
        };

        mode = lib.mkOption {
          type = lib.types.str;
          default = "0400";
          description = "Permissions mode for the decrypted secret";
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
      };
    }
  );

  decryptSecret = secret: ''
    target=${lib.escapeShellArg secret.path}
    tmp="$target.tmp"

    echo "decrypting ${lib.escapeShellArg secret.name} to $target"
    target_dir="$(dirname "$target")"
    if [ ! -d "$target_dir" ]; then
      install -d -m 0700 -o ${lib.escapeShellArg secret.owner} -g ${lib.escapeShellArg secret.group} "$target_dir"
    fi
    rm -f "$tmp"

    ${cfg.ageBin} --decrypt "''${identityArgs[@]}" -o "$tmp" ${lib.escapeShellArg secret.file}
    chmod ${secret.mode} "$tmp"
    chown ${secret.owner}:${secret.group} "$tmp"
    mv -f "$tmp" "$target"
  '';

  secretTargets = map (secret: secret.path) (lib.attrValues cfg.secrets);
in
{
  options.age = {
    ageBin = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.age}/bin/age";
      description = "age executable used to decrypt secrets";
    };

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

    managedPathsFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/system-manager/agenix-managed-secrets";
      description = "Manifest of secret paths managed by the age installer";
    };
  };

  config = lib.mkIf (cfg.secrets != { }) {
    assertions = [
      {
        assertion = cfg.identityPaths != [ ];
        message = "age.identityPaths must include at least one decryption identity.";
      }
    ];

    systemd.services.${serviceName} = {
      description = "Install age secrets";
      wantedBy = [ "system-manager.target" ];
      before = [ "system-manager.target" ];

      path = [
        pkgs.coreutils
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail

        identityArgs=()
        for identity in ${lib.escapeShellArgs cfg.identityPaths}; do
          if [ -r "$identity" ] && [ -s "$identity" ]; then
            identityArgs+=(-i "$identity")
          else
            echo "warning: age identity not readable: $identity" >&2
          fi
        done

        if [ "''${#identityArgs[@]}" -eq 0 ]; then
          echo "error: no readable age identities found in: ${lib.concatStringsSep " " cfg.identityPaths}" >&2
          exit 1
        fi

        ${lib.concatStringsSep "\n" (map decryptSecret (lib.attrValues cfg.secrets))}

        manifest=${lib.escapeShellArg cfg.managedPathsFile}
        desired="$(mktemp)"
        trap 'rm -f "$desired"' EXIT

        cat >"$desired" <<'EOF'
        ${lib.concatStringsSep "\n" secretTargets}
        EOF

        if [ -f "$manifest" ]; then
          while IFS= read -r managed_path; do
            if [ -n "$managed_path" ] && ! grep -Fx -- "$managed_path" "$desired" >/dev/null; then
              rm -f -- "$managed_path"
            fi
          done <"$manifest"
        fi

        install -d -m 0755 "$(dirname "$manifest")"
        install -m 0644 "$desired" "$manifest"
        trap - EXIT
        rm -f "$desired"
      '';
    };
  };
}
