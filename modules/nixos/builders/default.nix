{
  config,
  pkgs,
  lib,
  hostName,
  ...
}:

# ==============================================================================
# NixOS Distributed Builders
# ==============================================================================

let
  shared = import ../../shared.nix { inherit pkgs; };
  cfg = config.hakula.builders;

  allServers = builtins.attrValues shared.servers;
  servers = builtins.filter (s: s.name != hostName) allServers;
  builders = builtins.filter (s: s.isBuilder) servers;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.builders = {
    enable = lib.mkEnableOption "distributed builds using remote builders";
  };

  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Secrets (agenix)
    # --------------------------------------------------------------------------
    age.secrets.builder-ssh-key = {
      file = ../../../secrets/shared/builder-ssh-key.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    # --------------------------------------------------------------------------
    # Nix Configuration
    # --------------------------------------------------------------------------
    nix = {
      distributedBuilds = true;
      buildMachines = shared.mkBuildMachines builders config.age.secrets.builder-ssh-key.path;
      settings.builders-use-substitutes = true;
    };

    # --------------------------------------------------------------------------
    # SSH Configuration (system-wide)
    # --------------------------------------------------------------------------
    programs.ssh.extraConfig =
      shared.mkSshExtraConfig lib servers
        config.age.secrets.builder-ssh-key.path;

    programs.ssh.knownHosts = shared.mkSshKnownHosts lib servers;
  };
}
