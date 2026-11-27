# ==================================================================================================
# LLM Assistant Providers and Profiles
# ==================================================================================================

{
  config,
  lib,
  inputs,
  corpHosts,
  modelCatalog,
  secretPath,
  ...
}:

let
  inherit (config.hakula.llm-assistants.auth) enableCorpGateway;

  cfg = config.hakula.llm-assistants;

  oauthTokenSecret = "llm-assistants/claude-oauth-token";

  corpGateway = import ./corp-gateway.nix {
    inherit
      lib
      inputs
      corpHosts
      modelCatalog
      secretPath
      ;
  };

  thirdParty = import ./third-party {
    inherit lib secretPath;
  };

  # `agents.nix` picks the first listed API for families absent from its built-in `familyApis`,
  # and OMP only enables reasoning-effort compat and `/v1` routing on `openai-responses`.
  preferResponsesApi =
    model:
    if (model.channelId or { }) ? local && lib.elem "openai-responses" (model.apis or [ ]) then
      model
      // {
        apis = [ "openai-responses" ] ++ lib.remove "openai-responses" model.apis;
      }
    else
      model;

  requiredSecrets = [
    oauthTokenSecret
  ]
  ++ thirdParty.requiredSecrets
  ++ lib.optionals enableCorpGateway corpGateway.requiredSecrets;
in
{
  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------------------------
    # Models, providers, and profiles
    # ----------------------------------------------------------------------------------------------
    agents = {
      models = {
        catalog = lib.mapAttrs (_: preferResponsesApi) modelCatalog.models;
        inherit (modelCatalog) defaults;

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
        auth.profiles = corpGateway.claudeProfileOverrides;
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

      ccusage.pricingOverrides = lib.mkIf enableCorpGateway corpGateway.pricingOverrides;
    };

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = lib.genAttrs (lib.unique requiredSecrets) (_: { });
  };
}
