{
  config,
  lib,
  isNixOS ? false,
  ...
}:

# ==============================================================================
# Wakatime Configuration
# ==============================================================================

let
  homeDir = config.home.homeDirectory;
in
{
  # ----------------------------------------------------------------------------
  # Secrets (agenix)
  # On NixOS: system-level agenix handles decryption (modules/nixos/wakatime)
  # On Darwin / standalone: home-manager agenix handles decryption
  # ----------------------------------------------------------------------------
  config = lib.mkIf (!isNixOS) {
    age.identityPaths = [
      "${homeDir}/.ssh/id_ed25519"
    ];

    age.secrets.wakatime-config = {
      file = ../../../secrets/shared/wakatime-config.age;
      path = "${homeDir}/.wakatime.cfg";
      mode = "0600";
    };
  };
}
