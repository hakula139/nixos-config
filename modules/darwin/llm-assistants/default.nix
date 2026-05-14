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
  assistantSecrets = import ../../../lib/llm-assistants/secrets.nix {
    inherit secrets homeDir;
  };

  user = {
    name = cfg.user;
    home = homeDir;
  };

  requiredSecretAttrs = secrets.mkUserSecrets {
    names = requiredSecrets;
    inherit user;
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
        age.secrets =
          requiredSecretAttrs
          // secrets.mkUserSecretsFromSpecs {
            specs = assistantSecrets.mcp;
            inherit user;
            group = "staff";
          };
      }
    ]
  );
}
