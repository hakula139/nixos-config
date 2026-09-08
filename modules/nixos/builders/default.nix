# ==============================================================================
# NixOS Distributed Builders
# ==============================================================================

{
  config,
  lib,
  hostName,
  repoLib,
  servers,
  ...
}:

let
  cfg = config.hakula.builders;

  remoteServers = lib.filter (s: s.name != hostName) (lib.attrValues servers);
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.builders = {
    enable = lib.mkEnableOption "distributed builds using remote builders";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets.builder-ssh-key = repoLib.secrets.mkSecret {
      name = "builders/ssh-key";
      owner = "root";
      group = "root";
    };

    # --------------------------------------------------------------------------
    # Nix Configuration
    # --------------------------------------------------------------------------
    nix = {
      distributedBuilds = true;
      buildMachines = repoLib.ssh.mkBuildMachines remoteServers config.age.secrets.builder-ssh-key.path;
      settings.builders-use-substitutes = true;
    };

    # --------------------------------------------------------------------------
    # SSH Configuration (system-wide)
    # --------------------------------------------------------------------------
    programs.ssh.extraConfig = repoLib.ssh.mkExtraConfig remoteServers config.age.secrets.builder-ssh-key.path;

    programs.ssh.knownHosts = repoLib.ssh.mkKnownHosts remoteServers;
  };
}
