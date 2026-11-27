# ==================================================================================================
# LLM Assistant Providers and Profiles
# ==================================================================================================

{
  config,
  lib,
  inputs,
  corpHosts,
  modelPolicy,
  secretPath,
  ...
}:

let
  inherit (cfg.auth) enableCorpGateway;
  inherit (config.agents.resolved) modelCatalog;

  cfg = config.hakula.llm-assistants;
  builtinModelDefaults = inputs.agents-nix.lib.models.defaultCatalog.defaults;

  oauthTokenSecret = "llm-assistants/claude-oauth-token";

  profileEnabled = auth: name: auth.enabledProfiles == null || lib.elem name auth.enabledProfiles;

  defaultAnthropicGatewayProfile =
    auth:
    let
      name = "corp-gateway-anthropic";
    in
    lib.mkIf (enableCorpGateway && profileEnabled auth name) (lib.mkDefault name);

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
        catalog = modelPolicy.models;
        defaults = {
          inherit (modelPolicy) local;

          hybrid = {
            inherit (builtinModelDefaults.gemini) default flagship standard;
            inherit (modelPolicy.local) mini;
          };
        };
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
        auth.profileOverrides = lib.filterAttrs (
          name: _: profileEnabled config.agents.claude-code.auth name
        ) corpGateway.claudeProfileOverrides;
        statusline.costSources = corpGateway.costSources;
      };

      codex.auth = {
        allowedProviders = [ "corp-gateway" ];
        allowedChannels = [
          "openai"
          "local"
        ];
      };

      omp.auth.defaultProfile = defaultAnthropicGatewayProfile config.agents.omp.auth;

      oxide-code.auth.defaultProfile = defaultAnthropicGatewayProfile config.agents.oxide-code.auth;
    };

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = lib.genAttrs (lib.unique requiredSecrets) (_: { });
  };
}
