# ==================================================================================================
# Context7 Configuration
# ==================================================================================================

{
  config,
  lib,
  inputs,
  secretPath,
  ...
}:

{
  imports = [
    inputs.agents-nix.homeModules.ctx7
  ];

  config = lib.mkIf config.hakula.llm-assistants.enable {
    hakula.secrets.required."llm-assistants/mcp/context7-api-key" = { };

    agents.ctx7 = {
      enable = true;
      apiKeyFile = secretPath "llm-assistants/mcp/context7-api-key";
    };
  };
}
