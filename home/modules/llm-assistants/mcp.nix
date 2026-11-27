# ==================================================================================================
# LLM Assistant MCP Servers
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  secretPath,
  ...
}:

let
  cfg = config.hakula.llm-assistants;
  inherit (config.agents.resolved.mcp) computeEnabledServers;

  caSecret = "llm-assistants/corp-gateway/cachain.crt";
  claudeGatewayKeySecret = "llm-assistants/corp-gateway/api-key/claude-code";

  mcpServerSecrets = {
    atlassian = [
      "llm-assistants/mcp/confluence-pat"
    ];

    bifrost = [
      claudeGatewayKeySecret
      caSecret
    ];

    exa = [
      "llm-assistants/mcp/exa-api-key"
    ];

    gitlab = [
      "gitlab/pat"
    ];
  };

  mcpConfigs =
    lib.optional config.agents.claude-code.enable config.agents.claude-code.mcp
    ++ lib.optional config.agents.codex.enable config.agents.codex.mcp
    ++ lib.optional config.agents.omp.enable config.agents.omp.mcp
    ++ lib.optional config.hakula.cursor.enable config.hakula.cursor.mcp;

  activeServers = lib.unique (lib.concatMap computeEnabledServers mcpConfigs);
  requiredMcpSecretKeys = lib.unique (lib.concatMap (s: mcpServerSecrets.${s} or [ ]) activeServers);

  serverEnabled = name: !(lib.elem name cfg.mcp.disabledServers);
in
{
  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------------------------
    # MCP configuration
    # ----------------------------------------------------------------------------------------------
    agents.mcp = {
      inherit (cfg.mcp) disabledServers;
      uv.isolatedConfig = !config.hakula.corp-mirrors.enable;

      presets = {
        atlassian = {
          enable = serverEnabled "atlassian";
          url = corpHosts.wikiUrl;
          tokenFile = secretPath "llm-assistants/mcp/confluence-pat";
          # mcp-atlassian ignores NO_PROXY, so unset proxies for internal Confluence.
          clearProxy = true;
        };

        chromeDevtools.enable = serverEnabled "chromeDevtools";
        deepwiki.enable = serverEnabled "deepwiki";

        exa = {
          enable = serverEnabled "exa";
          apiKeyFile = secretPath "llm-assistants/mcp/exa-api-key";
        };

        github = {
          enable = serverEnabled "github";
          fallbackTokenFile = secretPath "github/pat";
        };

        gitlab = {
          enable = serverEnabled "gitlab";
          fallbackTokenFile = secretPath "gitlab/pat";
          fallbackApiUrl = "${corpHosts.gitlabUrl}/api/v4";
        };

        scrapling.enable = serverEnabled "scrapling";
      };

      servers = {
        # mcp-proxy sends API_ACCESS_TOKEN as a bearer token, which the gateway accepts in place of
        # x-bf-vk, keeping the key out of argv.
        bifrost = lib.mkIf (serverEnabled "bifrost") {
          displayName = "Bifrost";
          type = "stdio";
          command = [
            (lib.getExe pkgs.mcp-proxy)
            "--transport=streamablehttp"
            "--verify-ssl=${secretPath caSecret}"
            "${corpHosts.llmGatewayUrl}/mcp"
          ];
          envFiles.API_ACCESS_TOKEN = secretPath claudeGatewayKeySecret;
          permissions.allowTools = [
            "SearXNG-searxng_instance_info"
            "SearXNG-searxng_search_suggestions"
            "SearXNG-searxng_web_search"
            "SearXNG-web_url_read"
            "exa-web_fetch_exa"
            "exa-web_search_exa"
            "you-you-search"
          ];
        };

        mirrorCatalog = lib.mkIf (serverEnabled "mirrorCatalog") {
          displayName = "MirrorCatalog";
          type = "http";
          url = "${corpHosts.mirrorCatalogUrl}/mcp";
          permissions.allowTools = [
            "list_mirrors"
          ];
        };
      };
    };

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = lib.genAttrs requiredMcpSecretKeys (_: { });
  };
}
