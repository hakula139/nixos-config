# ==================================================================================================
# Agent Client Protocol (ACP)
# ==================================================================================================

{
  config,
  lib,
  inputs,
  ...
}:

{
  imports = [
    inputs.agents-nix.homeModules.acp
  ];

  config = lib.mkIf config.hakula.llm-assistants.enable {
    agents.acp.enable = true;
  };
}
