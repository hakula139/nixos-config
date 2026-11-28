# ==================================================================================================
# LLM Assistant MCP Servers
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  hostType,
  secretPath,
  ...
}:

let
  cfg = config.hakula.llm-assistants;

  corpServerNames = [
    "atlassian"
    "bifrost"
    "gitlab"
    "mirrorCatalog"
  ];

  caSecret = "llm-assistants/corp-gateway/cachain.crt";
  claudeGatewayKeySecret = "llm-assistants/corp-gateway/api-key/claude-code";
  confluencePatSecret = "llm-assistants/mcp/confluence-pat";
  exaApiKeySecret = "llm-assistants/mcp/exa-api-key";
  githubPatSecret = "github/pat";
  gitlabPatSecret = "gitlab/pat";

  mcpServerSecrets = {
    atlassian = [ confluencePatSecret ];
    bifrost = [
      claudeGatewayKeySecret
      caSecret
    ];
    exa = [ exaApiKeySecret ];
    github = [ githubPatSecret ];
    gitlab = [ gitlabPatSecret ];
  };

  serverEnabled = name: !(lib.elem name config.agents.mcp.disabledServers);

  requiredMcpSecretKeys = lib.unique (
    lib.concatLists (
      lib.mapAttrsToList (name: secrets: lib.optionals (serverEnabled name) secrets) mcpServerSecrets
    )
  );
in
{
  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------------------------
    # MCP configuration
    # ----------------------------------------------------------------------------------------------
    agents.mcp = {
      disabledServers = lib.mkIf (hostType == "personal") (lib.mkDefault corpServerNames);
      uv.isolatedConfig = !config.hakula.corp-mirrors.enable;

      presets = {
        atlassian = {
          enable = serverEnabled "atlassian";
          url = corpHosts.wikiUrl;
          tokenFile = secretPath confluencePatSecret;
          # mcp-atlassian ignores NO_PROXY, so unset proxies for internal Confluence.
          clearProxy = true;
        };

        chromeDevtools.enable = serverEnabled "chromeDevtools";

        deepwiki.enable = serverEnabled "deepwiki";

        exa = {
          enable = serverEnabled "exa";
          apiKeyFile = secretPath exaApiKeySecret;
        };

        github = {
          enable = serverEnabled "github";
          fallbackTokenFile = secretPath githubPatSecret;
        };

        gitlab = {
          enable = serverEnabled "gitlab";
          fallbackTokenFile = secretPath gitlabPatSecret;
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
