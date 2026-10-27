# ==================================================================================================
# MCP (Model Context Protocol) Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  corpGateway,
  corpHosts,
  clearProxyEnv,
  secretPath,
}:

let
  inherit (corpHosts) gitlabUrl wikiUrl;

  esc = lib.escapeShellArg;

  # ------------------------------------------------------------------------------------------------
  # MCP timeouts
  # ------------------------------------------------------------------------------------------------
  timeouts = {
    # Allow first-launch npm / uv downloads before MCP initialization completes.
    startup = 120;
  };

  # ------------------------------------------------------------------------------------------------
  # Server wrappers
  # ------------------------------------------------------------------------------------------------
  # undici (Node's built-in fetch) needs --use-env-proxy to honor HTTP_PROXY.
  nodejs = pkgs.nodejs_24;
  nodeSetup = ''
    export PATH="${nodejs}/bin:$PATH"
    export NODE_OPTIONS="''${NODE_OPTIONS:+$NODE_OPTIONS }--use-env-proxy"
  '';

  exportFromFile = var: file: ''
    if [ -f ${esc file} ]; then
      export ${var}="$(cat ${esc file})"
    fi
  '';

  exportLiteral = var: value: ''
    export ${var}=${esc value}
  '';

  # `envFiles` maps variables to runtime paths read on start, keeping secrets out of the store.
  # `envVars` values land in the store verbatim.
  mkServer =
    {
      name,
      command,
      envFiles ? { },
      envVars ? { },
      setup ? "",
    }:
    pkgs.writeShellScriptBin "${name}-mcp" (
      let
        exports = lib.concatStrings (
          lib.mapAttrsToList exportFromFile envFiles ++ lib.mapAttrsToList exportLiteral envVars
        );
      in
      ''
        set -euo pipefail
        ${exports}
        ${setup}
        exec ${lib.escapeShellArgs command} "$@"
      ''
    );

  mkNpmServer =
    server:
    mkServer (
      server
      // {
        setup = nodeSetup;
        command = [
          "npx"
          "-y"
        ]
        ++ server.command;
      }
    );

  # `@latest` refreshes the package on every start and ignores any `uv tool install` version, so
  # every host runs the newest release.
  mkUvServer =
    server:
    mkServer (
      server
      // {
        command = [ (lib.getExe' pkgs.uv "uvx") ] ++ server.command;
      }
    );

  # ------------------------------------------------------------------------------------------------
  # Atlassian (Confluence)
  # ------------------------------------------------------------------------------------------------
  atlassianBin = mkUvServer {
    name = "atlassian";
    command = [ "mcp-atlassian@latest" ];
    envFiles.CONFLUENCE_PERSONAL_TOKEN = secretPath "llm-assistants/mcp/confluence-pat";
    envVars.CONFLUENCE_URL = wikiUrl;
    # mcp-atlassian ignores NO_PROXY, so unset proxies for internal Confluence.
    setup = clearProxyEnv;
  };

  # ------------------------------------------------------------------------------------------------
  # Bifrost
  # ------------------------------------------------------------------------------------------------
  # mcp-proxy sends API_ACCESS_TOKEN as a bearer token, which the gateway accepts in place of
  # x-bf-vk, keeping the key out of argv.
  bifrostBin = mkServer {
    name = "bifrost";
    command = [
      (lib.getExe pkgs.mcp-proxy)
      "--transport=streamablehttp"
      "--verify-ssl=${secretPath corpGateway.caSecret}"
      "${corpGateway.baseUrl}/mcp"
    ];

    envFiles.API_ACCESS_TOKEN = secretPath (corpGateway.tokenSecretFor "claude-code");
  };

  # ------------------------------------------------------------------------------------------------
  # Brave Search
  # ------------------------------------------------------------------------------------------------
  braveSearchBin = mkNpmServer {
    name = "brave-search";
    command = [ "@brave/brave-search-mcp-server" ];
    envFiles.BRAVE_API_KEY = secretPath "llm-assistants/mcp/brave-api-key";
  };

  # ------------------------------------------------------------------------------------------------
  # Chrome DevTools
  # ------------------------------------------------------------------------------------------------
  chromeDevtoolsBin = mkNpmServer {
    name = "chrome-devtools";
    command = [
      "chrome-devtools-mcp"
      "--executable-path=${lib.getExe pkgs.browser-tools.chromium}"
      "--isolated"
    ]
    ++ lib.optionals (!pkgs.stdenv.isDarwin) [ "--headless" ];
  };

  # ------------------------------------------------------------------------------------------------
  # Exa
  # ------------------------------------------------------------------------------------------------
  exaBin = mkNpmServer {
    name = "exa";
    command = [ "exa-mcp-server" ];
    envFiles.EXA_API_KEY = secretPath "llm-assistants/mcp/exa-api-key";
    envVars.ENABLED_TOOLS = "web_search_exa,web_fetch_exa,web_search_advanced_exa,agent_run";
  };

  # ------------------------------------------------------------------------------------------------
  # GitHub
  # ------------------------------------------------------------------------------------------------
  ghBin = lib.getExe config.programs.gh.package;
  githubBin = mkServer {
    name = "github";
    command = [
      (lib.getExe pkgs.mcp-server-github)
      "stdio"
    ];

    setup = ''
      if [[ -z "''${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]] \
        && token=$(${esc ghBin} auth token 2>/dev/null); then
        export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
      fi
    '';
  };

  # ------------------------------------------------------------------------------------------------
  # GitLab
  # ------------------------------------------------------------------------------------------------
  glabBin = lib.getExe pkgs.glab;
  gitlabPatFile = secretPath "gitlab/pat";
  gitlabToolsets = lib.concatStringsSep "," [
    "branches"
    "issues"
    "labels"
    "merge_requests"
    "pipelines"
    "projects"
    "repositories"
  ];

  gitlabBin = mkServer {
    name = "gitlab";
    command = [ (lib.getExe pkgs.mcp-server-gitlab) ];
    envVars.GITLAB_TOOLSETS = gitlabToolsets;
    setup = ''
      if host=$(${esc glabBin} config get host 2>/dev/null) && [[ -n "$host" ]] \
        && token=$(${esc glabBin} config get token --host "$host" 2>/dev/null) \
        && [[ -n "$token" ]]; then
        export GITLAB_PERSONAL_ACCESS_TOKEN="$token"
        export GITLAB_API_URL="https://''${host}/api/v4"
      elif [[ -f ${esc gitlabPatFile} ]]; then
        export GITLAB_PERSONAL_ACCESS_TOKEN="$(cat ${esc gitlabPatFile})"
        export GITLAB_API_URL=${esc "${gitlabUrl}/api/v4"}
      fi
    '';
  };

  # ------------------------------------------------------------------------------------------------
  # Scrapling
  # ------------------------------------------------------------------------------------------------
  scraplingBin = mkUvServer {
    name = "scrapling";
    command = [
      "--from"
      "scrapling[ai]@latest"
      "scrapling-mcp"
      "--executable-path=${lib.getExe pkgs.browser-tools.chromium}"
    ];
  };
in
{
  inherit timeouts;

  # ------------------------------------------------------------------------------------------------
  # MCP servers
  # ------------------------------------------------------------------------------------------------
  servers = {
    atlassian = {
      command = lib.getExe atlassianBin;
      type = "stdio";
    };

    bifrost = {
      command = lib.getExe bifrostBin;
      type = "stdio";
    };

    braveSearch = {
      command = lib.getExe braveSearchBin;
      type = "stdio";
    };

    chromeDevtools = {
      command = lib.getExe chromeDevtoolsBin;
      type = "stdio";
    };

    deepwiki = {
      type = "http";
      url = "https://mcp.deepwiki.com/mcp";
    };

    exa = {
      command = lib.getExe exaBin;
      type = "stdio";
    };

    github = {
      command = lib.getExe githubBin;
      type = "stdio";
    };

    gitlab = {
      command = lib.getExe gitlabBin;
      type = "stdio";
    };

    scrapling = {
      command = lib.getExe scraplingBin;
      type = "stdio";
    };
  };
}
