# ==============================================================================
# LLM Assistants Integration
# ==============================================================================

{
  config,
  lib,
  ...
}:

let
  cfg = config.hakula.llm-assistants;
  llmAssistants = import ../../../lib/llm-assistants { inherit lib; };
in
{
  options.hakula.llm-assistants = llmAssistants.mkOptions {
    enableDescription = "LLM assistants for the primary Home Manager user";
    defaultUser = "hakula";
  };

  config = lib.mkIf cfg.enable (llmAssistants.mkHomeManagerConfig cfg);
}
