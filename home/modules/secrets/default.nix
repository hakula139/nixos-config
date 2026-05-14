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
    submodule (
      { name, ... }:
      {
        options = {
          name = lib.mkOption {
            type = str;
            default = name;
            description = "Secret path under the repository secrets directory";
          };

          path = lib.mkOption {
            type = str;
            default = secrets.secretPath name;
            description = "Absolute path where the decrypted secret is installed";
          };
        };
      }
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
