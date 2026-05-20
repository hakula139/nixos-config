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
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.llm-assistants = llmAssistantLib.mkOptions {
    inherit proxyLib;
    enableDescription = "LLM assistants for the primary Home Manager user";
    defaultUser = "hakula";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (llmAssistantLib.mkHomeManagerConfig cfg);
}
