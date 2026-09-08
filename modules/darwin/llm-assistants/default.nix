# ==============================================================================
# LLM Assistants Integration
# ==============================================================================

{
  config,
  lib,
  repoLib,
  ...
}:

let
  cfg = config.hakula.llm-assistants;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.llm-assistants = repoLib.llmAssistants.mkOptions {
    inherit (repoLib.proxy) mkProxyOptions;
    enableDescription = "LLM assistants for the primary Home Manager user";
    defaultUser = "hakula";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (repoLib.llmAssistants.mkHomeManagerConfig cfg);
}
