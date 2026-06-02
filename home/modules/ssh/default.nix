# ==============================================================================
# SSH Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  options,
  sharedConfig,
  ...
}:

let
  shared = sharedConfig { inherit pkgs lib; };
  homeDir = config.home.homeDirectory;

  serverMatchBlocks = lib.mapAttrs' (
    _: server:
    lib.nameValuePair server.displayName {
      host = server.displayName;
      hostname = server.ip;
      user = "hakula";
      inherit (server) port;
      identityFile = "${homeDir}/.ssh/${server.provider}/id_ed25519";
      forwardAgent = true;
    }
  ) shared.servers;

  sshBlocks = {
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
      proxyCommand = "tailscale nc %h %p";
      forwardAgent = true;
    };
    "Hakula-Work" = {
      host = "Hakula-Work";
      hostname = "hakula-work";
      user = "hakula";
      port = 22;
      identityFile = "${homeDir}/.ssh/id_ed25519";
      proxyCommand = "tailscale nc %h %p";
      forwardAgent = true;
    };
  }
  // serverMatchBlocks;

  mkSettings =
    block:
    lib.optionalAttrs (block ? hostname) { HostName = block.hostname; }
    // lib.optionalAttrs (block ? user) { User = block.user; }
    // lib.optionalAttrs (block ? port) { Port = block.port; }
    // lib.optionalAttrs (block ? identityFile) { IdentityFile = block.identityFile; }
    // lib.optionalAttrs (block ? proxyCommand) { ProxyCommand = block.proxyCommand; }
    // lib.optionalAttrs (block ? forwardAgent) { ForwardAgent = block.forwardAgent; };
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
  }
  // (
    if builtins.hasAttr "settings" options.programs.ssh then
      { settings = lib.mapAttrs (_: mkSettings) sshBlocks; }
    else
      { matchBlocks = sshBlocks; }
  );
}
