# ==============================================================================
# LLM Assistants Integration
# ==============================================================================

{
  config,
  lib,
  secrets,
  ...
}:

let
  cfg = config.hakula.llm-assistants;
  llmAssistants = import ../../../lib/llm-assistants { inherit lib; };
  hmUser = config.home-manager.users.${cfg.user} or { };
  userCfg = config.users.users.${cfg.user};
  homeDir = userCfg.home or "/Users/${cfg.user}";
  requiredSecrets = hmUser.hakula.claude-code.auth._provision.requiredSecrets or [ ];

  user = {
    name = cfg.user;
    home = homeDir;
  };

  requiredSecretAttrs = secrets.mkUserSecrets {
    names = requiredSecrets;
    inherit user;
    group = "staff";
  };

  mkUserSecret =
    name:
    secrets.mkUserSecret {
      inherit name user;
      group = "staff";
    };
in
{
  options.hakula.llm-assistants = llmAssistants.mkOptions {
    enableDescription = "LLM assistants for the primary Home Manager user";
    defaultUser = "hakula";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (llmAssistants.mkHomeManagerConfig cfg)

      {
        age.secrets = requiredSecretAttrs // {
          confluence-pat = mkUserSecret "llm-assistants/mcp/confluence-pat";
          brave-api-key = mkUserSecret "llm-assistants/mcp/brave-api-key";
          context7-api-key = mkUserSecret "llm-assistants/mcp/context7-api-key";
          github-pat = (mkUserSecret "github/pat-personal") // {
            path = "${homeDir}/.secrets/github/pat";
          };
        };
      }
    ]
  );
}
