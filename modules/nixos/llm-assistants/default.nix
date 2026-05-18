# ==============================================================================
# LLM Assistants Integration
# ==============================================================================

{
  config,
  lib,
  llmAssistantLib,
  proxyLib,
  ...
}:

let
  cfg = config.hakula.llm-assistants;
in
{
  imports = [
    ./claude-code
  ];

  options.hakula.llm-assistants = llmAssistantLib.mkOptions {
    inherit proxyLib;
    enableDescription = "LLM assistants for the primary interactive user";
    defaultUser = config.hakula.user.name;
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        hakula.claude-code.enable = lib.mkDefault true;
      }

      (llmAssistantLib.mkHomeManagerConfig cfg)
    ]
  );
}
