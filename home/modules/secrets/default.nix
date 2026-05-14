# ==============================================================================
# Secret Requirements
# ==============================================================================

{ lib, ... }:

let
  secretSpecType = lib.types.submodule (
    { name, ... }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Secret path under the repository secrets directory";
        };

        file = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Encrypted age file backing the secret";
        };

        path = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Absolute path where the decrypted secret is installed";
        };

        mode = lib.mkOption {
          type = lib.types.str;
          default = "0400";
          description = "Permissions mode for the decrypted secret";
        };

        group = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Group override for the decrypted secret";
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
}
