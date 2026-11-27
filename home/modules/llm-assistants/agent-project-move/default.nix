# ==================================================================================================
# Agent Project Move
# ==================================================================================================

{
  config,
  lib,
  inputs,
  ...
}:

{
  imports = [
    inputs.agents-nix.homeModules.agent-project-move
  ];

  config = lib.mkIf config.hakula.llm-assistants.enable {
    agents.agent-project-move.enable = true;
  };
}
