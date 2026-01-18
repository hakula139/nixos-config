{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# SSH Configuration
# ==============================================================================

let
  shared = import ../../../modules/shared.nix { inherit pkgs; };
  homeDir = config.home.homeDirectory;

  serverMatchBlocks = lib.mapAttrs' (
    _: server:
    lib.nameValuePair server.displayName {
      host = server.displayName;
      hostname = server.ip;
      user = "hakula";
      port = server.port;
      identityFile = "${homeDir}/.ssh/${server.provider}/id_ed25519";
      forwardAgent = true;
    }
  ) shared.servers;
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = { };
      "github.com-hakula139" = {
        host = "github.com-hakula139";
        hostname = "github.com";
        user = "git";
        identityFile = "${homeDir}/.ssh/GitHub/hakula139";
      };
      "github.com-hc492874" = {
        host = "github.com-hc492874";
        hostname = "github.com";
        user = "git";
        identityFile = "${homeDir}/.ssh/GitHub/hc492874";
      };
      "Hakula-MacBook" = {
        host = "Hakula-MacBook";
        hostname = "hakula-macbook";
        user = "hakula";
        port = 22;
        identityFile = "${homeDir}/.ssh/id_ed25519";
        forwardAgent = true;
      };
    }
    // serverMatchBlocks;
  };
}
