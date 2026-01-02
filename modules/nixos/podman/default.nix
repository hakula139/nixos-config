{ lib, ... }:

# ==============================================================================
# Podman (Container Runtime)
# ==============================================================================

{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.podman = {
    network = {
      subnet = lib.mkOption {
        type = lib.types.str;
        default = "10.88.0.0/16";
        description = "Default Podman bridge network subnet";
      };

      gateway = lib.mkOption {
        type = lib.types.str;
        default = "10.88.0.1";
        description = "Default Podman bridge network gateway IP";
      };
    };
  };
}
