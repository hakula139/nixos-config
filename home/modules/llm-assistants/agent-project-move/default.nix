# ==================================================================================================
# Agent Project Move
# ==================================================================================================

{
  config,
  lib,
  ...
}:

lib.mkIf config.hakula.llm-assistants.enable {
  programs.agent-project-move = {
    enable = true;
    skillDirectories = [ ];
  };
}
