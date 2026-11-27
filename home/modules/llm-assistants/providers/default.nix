# ==================================================================================================
# LLM Assistant Providers and Profiles
# ==================================================================================================

{
  config,
  lib,
  corpHosts,
  modelCatalog,
  secretPath,
  ...
}:

let
  inherit (cfg.auth) enableCorpGateway;

  cfg = config.hakula.llm-assistants;

  oauthTokenSecret = "llm-assistants/claude-oauth-token";

  corpGateway = import ./corp-gateway.nix {
    inherit
      lib
      corpHosts
      modelCatalog
      secretPath
      ;
  };

  thirdParty = import ./third-party {
    inherit lib secretPath;
  };

  requiredSecrets = [
    oauthTokenSecret
  ]
  ++ thirdParty.requiredSecrets
  ++ lib.optionals enableCorpGateway corpGateway.requiredSecrets;
in
{
  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------------------------
    # Agents
    # ----------------------------------------------------------------------------------------------
    agents = {
      # --------------------------------------------------------------------------------------------
      # Models, providers, and profiles
      # --------------------------------------------------------------------------------------------
      models = {
        catalog = modelCatalog.models;
        inherit (modelCatalog) defaults;
        familyApis.local = "openai-responses";

        workloadPolicy.local = {
          default = "high";
          flagship = "max";
          standard = "high";
          mini = "low";
        };
      };

      providers = thirdParty.providers // lib.optionalAttrs enableCorpGateway corpGateway.providers;

      profiles = {
        official-token = {
          provider = null;
          oauthTokenFile = secretPath oauthTokenSecret;
          family = "claude";
          nativeWebSearch = true;
          clients = [
            "claude-code"
            "oxide-code"
          ];
        };
      }
      // thirdParty.profiles
      // lib.optionalAttrs enableCorpGateway corpGateway.profiles;

      modelCall = lib.mkIf enableCorpGateway corpGateway.modelCall;

      # --------------------------------------------------------------------------------------------
      # Per-assistant profile routing
      # --------------------------------------------------------------------------------------------
      claude-code = lib.mkIf enableCorpGateway {
        auth.profileOverrides = corpGateway.claudeProfileOverrides;
        statusline.costSources = corpGateway.costSources;
      };

      codex.auth = {
        allowedProviders = [ "corp-gateway" ];
        allowedChannels = [
          "openai"
          "local"
        ];
      };

      omp.auth.defaultProfile = lib.mkDefault (
        if enableCorpGateway then "corp-gateway-anthropic" else "official"
      );

      oxide-code.auth.defaultProfile = lib.mkDefault (
        if enableCorpGateway then "corp-gateway-anthropic" else "official"
      );
    };

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = lib.genAttrs (lib.unique requiredSecrets) (_: { });
  };
}
