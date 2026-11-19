# ==================================================================================================
# Podman (Container Runtime)
# ==================================================================================================

{
  lib,
  ...
}:

{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.podman = {
    network = {
      interface = lib.mkOption {
        type = lib.types.str;
        default = "podman0";
        description = "Default Podman bridge network interface";
      };

      subnet = lib.mkOption {
        type = lib.types.str;
        default = "10.88.0.0/16";
        description = "Default Podman bridge network subnet";
      };
    };
  };
}
