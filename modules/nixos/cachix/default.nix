{
  config,
  lib,
  secrets,
  ...
}:

# ==============================================================================
# Cachix (Binary Cache Tooling)
# ==============================================================================

let
  cfg = config.hakula.cachix;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.cachix = {
    enable = lib.mkEnableOption "Cachix auth token secret";
  };

  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------
    age.secrets.cachix-auth-token = secrets.mkSecret {
      name = "cachix-auth-token";
      owner = "hakula";
      group = "users";
    };
  };
}
