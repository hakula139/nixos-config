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
in
{
  options.hakula.secrets.required = lib.mkOption {
    type = lib.types.attrsOf secretSpecType;
    default = { };
    description = "User-owned age secrets required by this Home Manager configuration";
  };

  # Resolver exposed as a module argument so consumers can take it as a
  # plain function parameter instead of routing through `config.hakula.*`.
  config._module.args.secretPath = name: config.hakula.secrets.required.${name}.path;
}
