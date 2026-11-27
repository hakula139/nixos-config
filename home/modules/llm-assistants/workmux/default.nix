# ==================================================================================================
# Workmux Agent Orchestration
# ==================================================================================================

{
  config,
  lib,
  inputs,
  ...
}:

{
  imports = [
    inputs.agents-nix.homeModules.workmux
  ];

  config = lib.mkIf config.hakula.llm-assistants.enable {
    agents.workmux = {
      enable = true;
      # Explicitly enable while OMP still uses the local nixos-config module.
      installOmpExtension = true;
    };
  };
}
