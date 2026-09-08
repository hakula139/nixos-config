# ==============================================================================
# SSH Configuration
# ==============================================================================

{
  config,
  lib,
  servers,
  ...
}:

let
  homeDir = config.home.homeDirectory;

  serverSettings = lib.mapAttrs' (
    _: server:
    lib.nameValuePair server.displayName {
      HostName = server.ip;
      User = "hakula";
      Port = server.port;
      IdentityFile = "${homeDir}/.ssh/${server.provider}/id_ed25519";
      ForwardAgent = true;
    }
  ) servers;
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = { };
      "github.com-hakula139" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "${homeDir}/.ssh/GitHub/hakula139";
      };
      "github.com-hc492874" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "${homeDir}/.ssh/GitHub/hc492874";
      };
      "Hakula-MacBook" = {
        HostName = "hakula-macbook";
        User = "hakula";
        Port = 22;
        IdentityFile = "${homeDir}/.ssh/id_ed25519";
        ProxyCommand = "tailscale nc %h %p";
        ForwardAgent = true;
      };
      "Hakula-Work" = {
        HostName = "wsl";
        User = "hakula";
        Port = 35060;
        IdentityFile = "${homeDir}/.ssh/id_ed25519";
        ProxyCommand = "tailscale nc %h %p";
        ForwardAgent = true;
      };
    }
    // serverSettings;
  };
}
