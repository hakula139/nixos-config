# ==============================================================================
# ccusage Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  modelCatalog,
  ...
}:

let
  cfg = config.hakula.ccusage;

  json = pkgs.formats.json { };

  # Transcripts log the model id the gateway returns, which drops the routing
  # prefix: `openrouter/anthropic/claude-opus-5.5` is logged as
  # `anthropic/claude-opus-5.5`.
  loggedModelId =
    gatewayId:
    let
      segments = lib.splitString "/" gatewayId;
    in
    if builtins.length segments > 1 then lib.concatStringsSep "/" (lib.tail segments) else gatewayId;

  perToken = costPerMillion: costPerMillion / 1000000.0;

  pricingOverrides = lib.listToAttrs (
    lib.concatLists (
      lib.mapAttrsToList (
        _: model:
        lib.mapAttrsToList (
          gateway: cost:
          lib.nameValuePair (loggedModelId model.gatewayId.${gateway}) {
            inputCostPerToken = perToken cost.input;
            outputCostPerToken = perToken cost.output;
            cacheCreationInputTokenCost = perToken cost.cacheWrite;
            cacheReadInputTokenCost = perToken cost.cacheRead;
          }
        ) model.gatewayCost
      ) modelCatalog.models
    )
  );
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.ccusage = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install ccusage and configure its usage stores";
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Packages
    # --------------------------------------------------------------------------
    home.packages = [ pkgs.ccusage ];

    # --------------------------------------------------------------------------
    # Configuration files
    # --------------------------------------------------------------------------
    # ccusage discovers configuration for all agents in the Claude directory.
    xdg.configFile."claude/ccusage.json".source = json.generate "ccusage.json" {
      defaults = { inherit pricingOverrides; };
      pi.stores = [
        {
          name = "omp";
          path = "${config.home.homeDirectory}/.omp/agent/sessions";
        }
      ];
    };
  };
}
