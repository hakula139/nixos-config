# ==================================================================================================
# OMP Model Configuration
# ==================================================================================================

{
  pkgs,
  lib,
  profileDefinitions,
  profiles,
  secretPath,
}:

let
  inherit (profileDefinitions) providers;

  mkModel = channel: model: {
    inherit (model)
      name
      contextWindow
      maxTokens
      input
      reasoning
      thinking
      ;
    id = model.channelId.${channel};
    cost = model.channelCost.${channel};
  };

  # Every workload of one source shares its API, channel, and family.
  sourceWorkloads = lib.groupBy (workload: workload.source) (
    lib.concatMap (profile: builtins.attrValues profile.workloads) (builtins.attrValues profiles)
  );

  mkProvider =
    source: workloads:
    let
      inherit (lib.head workloads) api channel family;
      provider = providers.${profiles.${source}.provider};
      tokenFile = secretPath (provider.tokenSecretFor "omp");
    in
    {
      inherit api;
      baseUrl = provider.apiUrls.${api};
      auth = "apiKey";
      apiKey = "!${lib.getExe' pkgs.coreutils "cat"} ${lib.escapeShellArg tokenFile}";
      authHeader = true;
      headers = provider.extraHeaders or { };
      models = map (mkModel channel) (lib.unique (map (workload: workload.model) workloads));
    }
    // lib.optionalAttrs (family == "claude") {
      compat.supportsLongCacheRetention = true;
    }
    // lib.optionalAttrs (api == "openai-responses") {
      compat = {
        # Override unrelated bundled-provider compat inherited by custom models.
        supportsReasoningEffort = true;
      }
      // lib.optionalAttrs (family == "gpt") {
        supportsLongPromptCacheRetention = true;
      };
    };
in
{
  providers = lib.mapAttrs mkProvider sourceWorkloads;
}
