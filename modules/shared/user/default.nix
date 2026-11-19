# ==================================================================================================
# Primary User
# ==================================================================================================
# Declares the user options shared by the NixOS, Darwin, and System Manager trees. Each tree wires
# them into its own `users.users` definition.
# ==================================================================================================

{
  lib,
  ...
}:

{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula = {
    user = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "hakula";
        description = "Primary user account name";
      };

      group = lib.mkOption {
        type = lib.types.str;
        description = "Primary group of the user, which owns the user's secrets";
      };
    };

    access.ssh.authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorized for user login";
    };
  };
}
