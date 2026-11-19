# ==================================================================================================
# ccusage Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  modelCatalog,
  ...
}:

let
  inherit (config.lib.llmAssistants) configDirs;
  inherit (repoLib.llmAssistants) channelIds;

  cfg = config.hakula.llm-assistants;
  json = pkgs.formats.json { };

  perToken = rate: rate / 1000000.0;

  mkPricingOverride = cost: {
    inputCostPerToken = perToken cost.input;
    outputCostPerToken = perToken cost.output;
    cacheReadInputTokenCost = perToken cost.cacheRead;
    cacheCreationInputTokenCost = perToken cost.cacheWrite;
  };

  # The offline LiteLLM snapshot is stale and prices local models at reseller rates, so override
  # it from the catalog's billed costs.
  pricingOverrides = lib.concatMapAttrs (
    _: model:
    lib.concatMapAttrs (
      channel: channelId:
      lib.genAttrs (channelIds channelId) (_: mkPricingOverride model.channelBilledCost.${channel})
    ) model.channelId
  ) modelCatalog.models;
in
lib.mkIf cfg.enable {
  # ------------------------------------------------------------------------------------------------
  # Packages
  # ------------------------------------------------------------------------------------------------
  home.packages = [
    pkgs.ccusage
  ];

  # ------------------------------------------------------------------------------------------------
  # Configuration files
  # ------------------------------------------------------------------------------------------------
  # ccusage discovers configuration for all agents in the Claude directory.
  xdg.configFile."claude/ccusage.json".source = json.generate "ccusage.json" (
    {
      pi.stores = [
        {
          name = "omp";
          path = "${configDirs.omp}/sessions";
        }
      ];
    }
    // lib.optionalAttrs cfg.auth.enableCorpGateway {
      claude.defaults.pricingOverrides = pricingOverrides;
    }
  );
}
