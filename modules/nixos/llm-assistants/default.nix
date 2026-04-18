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
  imports = [
    ./claude-code
    ./mcp
  ];

  options.hakula.llm-assistants = llmAssistants.mkOptions {
    enableDescription = "LLM assistants for the primary interactive user";
    defaultUser = config.hakula.user.name;
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        hakula.claude-code.enable = lib.mkDefault true;
        hakula.mcp.enable = lib.mkDefault true;
      }

      (llmAssistants.mkHomeManagerConfig cfg)
    ]
  );
}
