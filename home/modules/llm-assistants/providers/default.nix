# ==================================================================================================
# LLM Assistant Providers and Profiles
# ==================================================================================================

{
  config,
  lib,
  inputs,
  repoLib,
  corpHosts,
  modelPolicy,
  secretPath,
  ...
}:

let
  inherit (cfg.auth) enableCorpGateway;
  inherit (repoLib.agents) mkGatewayDefaultProfile;
  inherit (config.agents.resolved) clientProfiles modelCatalog;

  cfg = config.hakula.llm-assistants;
  builtinModelDefaults = inputs.agents-nix.lib.models.defaultCatalog.defaults;
  geminiDefaults = config.agents.models.defaults.gemini or { };
  resolvedClaudeProfiles = clientProfiles.claude-code;

  oauthTokenSecret = "llm-assistants/claude-oauth-token";

  corpGateway = import ./corp-gateway.nix {
    inherit
      lib
      corpHosts
      modelCatalog
      resolvedClaudeProfiles
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
          local = lib.mapAttrs (_: lib.mkDefault) modelPolicy.local;

          hybrid = {
            default = lib.mkDefault (geminiDefaults.default or builtinModelDefaults.gemini.default);
            flagship = lib.mkDefault (geminiDefaults.flagship or builtinModelDefaults.gemini.flagship);
            standard = lib.mkDefault (geminiDefaults.standard or builtinModelDefaults.gemini.standard);
            mini = lib.mkDefault config.agents.models.defaults.local.mini;
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
          name: _: resolvedClaudeProfiles ? ${name}
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

      omp.auth.defaultProfile = mkGatewayDefaultProfile config "omp" "corp-gateway-anthropic";

      oxide-code.auth.defaultProfile =
        mkGatewayDefaultProfile config "oxide-code"
          "corp-gateway-anthropic";
    };

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = lib.genAttrs (lib.unique requiredSecrets) (_: { });
  };
}
