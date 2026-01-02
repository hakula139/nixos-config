{ lib, config, ... }:

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
    # Secrets (agenix)
    # ----------------------------------------------------------------------------
    age.secrets.cachix-auth-token = {
      file = ../../../secrets/shared/cachix-auth-token.age;
      owner = "hakula";
      group = "users";
      mode = "0400";
    };
  };
}
