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
  imports = [
    ./claude-code
  ];

  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.llm-assistants = repoLib.llmAssistants.mkOptions {
    inherit (repoLib.proxy) mkProxyOptions;
    enableDescription = "LLM assistants for the primary interactive user";
    defaultUser = config.hakula.user.name;
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        hakula.claude-code.enable = lib.mkDefault true;
      }

      (repoLib.llmAssistants.mkHomeManagerConfig cfg)
    ]
  );
}
