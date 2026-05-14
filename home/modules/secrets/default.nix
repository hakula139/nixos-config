# ==============================================================================
# Secret Requirements
# ==============================================================================

{
  config,
  lib,
  secrets,
  ...
}:

let
  secretSpecType =
    with lib.types;
    coercedTo str (path: { inherit path; }) (
      submodule (
        { name, ... }:
        {
          options = {
            name = lib.mkOption {
              type = str;
              default = name;
              description = "Secret path under the repository secrets directory";
            };

            file = lib.mkOption {
              type = nullOr path;
              default = null;
              description = "Encrypted age file backing the secret";
            };

            path = lib.mkOption {
              type = nullOr str;
              default = secrets.secretPath name;
              description = "Absolute path where the decrypted secret is installed";
            };

            mode = lib.mkOption {
              type = str;
              default = "0400";
              description = "Permissions mode for the decrypted secret";
            };

            group = lib.mkOption {
              type = nullOr str;
              default = null;
              description = "Group override for the decrypted secret";
            };
          };
        }
      )
    );

  resolveSecretPath = name: config.hakula.secrets.required.${name}.path;
in
{
  options.hakula.secrets = {
    required = lib.mkOption {
      type = lib.types.attrsOf secretSpecType;
      default = { };
      description = "User-owned age secrets required by this Home Manager configuration";
    };

    path = lib.mkOption {
      type = lib.types.functionTo lib.types.str;
      default = resolveSecretPath;
      readOnly = true;
      description = "Resolve a declared user secret to its decrypted runtime path";
    };
  };
}
