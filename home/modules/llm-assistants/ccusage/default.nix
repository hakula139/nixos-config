# ==================================================================================================
# ccusage Configuration
# ==================================================================================================

{
  config,
  lib,
  inputs,
  repoLib,
  modelCatalog,
  ...
}:

let
  inherit (config.lib.llmAssistants) configDirs;
  inherit (repoLib.llmAssistants) channelIds;

  cfg = config.hakula.llm-assistants;

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
{
  imports = [
    inputs.agents-nix.homeModules.ccusage
  ];

  config = lib.mkIf cfg.enable {
    agents.ccusage = {
      enable = true;

      # Explicitly register the OMP store while OMP still uses the local nixos-config module.
      piStores = [
        {
          name = "omp";
          path = "${configDirs.omp}/sessions";
        }
      ];

      pricingOverrides = lib.mkIf cfg.auth.enableCorpGateway pricingOverrides;
    };
  };
}
