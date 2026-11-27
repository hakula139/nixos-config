# ==================================================================================================
# Claude Code Statusline
# ==================================================================================================

{
  lib,
  corpHosts,
  modelCatalog,
  secretPath,
  enableCorpGateway,
}:

{
  enable = true;

  settings = {
    models = lib.concatMapAttrs (
      id: model: lib.genAttrs ([ id ] ++ builtins.attrValues model.channelId) (_: model.name)
    ) modelCatalog.models;
  }
  // lib.optionalAttrs enableCorpGateway {
    cost_sources = [
      {
        id = "corp-gateway";

        match.env_prefix = {
          ANTHROPIC_BASE_URL = corpHosts.llmGatewayUrl;
        };

        source = {
          type = "http";
          url = "${corpHosts.llmGatewayPortalUrl}/api/portal/monitoring/kpi";
          query = {
            start_time = "{start_utc}";
            end_time = "{end_utc}";
            owner = "self";
          };
          auth = {
            type = "bearer_file";
            path = secretPath "llm-assistants/corp-gateway/portal-token";
          };
          ca_file = secretPath "llm-assistants/corp-gateway/cachain.crt";
          no_proxy = true;
          extract = [
            "current"
            "total_cost"
          ];
        };

        behavior.show_block = false;
      }
    ];
  };
}
