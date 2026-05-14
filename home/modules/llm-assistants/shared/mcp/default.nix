# ==============================================================================
# MCP (Model Context Protocol) Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  secrets,
  corpDomain,
  llmAssistantLib,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  assistantSecrets = llmAssistantLib.mkSecretSpecs {
    inherit secrets homeDir;
  };

  # Node.js's built-in fetch (undici) ignores HTTP_PROXY / HTTPS_PROXY by
  # default. --use-env-proxy makes it honour the env vars, which is required
  # on hosts that route traffic through a proxy.
  nodejs = pkgs.nodejs_24;
  nodeSetup = ''
    export PATH="${nodejs}/bin:$PATH"
    export NODE_OPTIONS="''${NODE_OPTIONS:+$NODE_OPTIONS }--use-env-proxy"
  '';

  # ----------------------------------------------------------------------------
  # Atlassian (Confluence)
  # ----------------------------------------------------------------------------
  confluencePatFile = assistantSecrets.mcp.confluence-pat.path;
  atlassianBin = pkgs.writeShellScriptBin "atlassian-mcp" ''
    export PATH="${pkgs.uv}/bin:$PATH"
    if [ -f "${confluencePatFile}" ]; then
      export CONFLUENCE_PERSONAL_TOKEN="$(cat ${confluencePatFile})"
    fi
    export CONFLUENCE_URL="https://wiki.${corpDomain}"
    # mcp-atlassian reads HTTP(S)_PROXY into session.proxies but ignores NO_PROXY
    # due to trust_env=False (PAT auth). Unset proxy for internal Confluence.
    unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
    exec uvx mcp-atlassian "$@"
  '';

  # ----------------------------------------------------------------------------
  # Brave Search
  # ----------------------------------------------------------------------------
  braveApiKeyFile = assistantSecrets.mcp.brave-api-key.path;
  braveSearchBin = pkgs.writeShellScriptBin "brave-search-mcp" ''
    ${nodeSetup}
    if [ -f "${braveApiKeyFile}" ]; then
      export BRAVE_API_KEY="$(cat ${braveApiKeyFile})"
    fi
    exec npx -y @brave/brave-search-mcp-server "$@"
  '';

  # ----------------------------------------------------------------------------
  # Codex
  # ----------------------------------------------------------------------------
  codexBin = pkgs.writeShellScriptBin "codex-mcp" ''
    exec "${config.home.profileDirectory}/bin/codex" mcp-server "$@"
  '';

  # ----------------------------------------------------------------------------
  # Context7
  # ----------------------------------------------------------------------------
  context7ApiKeyFile = assistantSecrets.mcp.context7-api-key.path;
  context7Bin = pkgs.writeShellScriptBin "context7-mcp" ''
    ${nodeSetup}
    if [ -f "${context7ApiKeyFile}" ]; then
      export CONTEXT7_API_KEY="$(cat ${context7ApiKeyFile})"
    fi
    exec npx -y @upstash/context7-mcp "$@"
  '';

  # ----------------------------------------------------------------------------
  # DeepWiki
  # ----------------------------------------------------------------------------
  deepwikiBin = pkgs.writeShellScriptBin "deepwiki-mcp" ''
    ${nodeSetup}
    exec npx -y mcp-remote https://mcp.deepwiki.com/mcp --transport http-first "$@"
  '';

  # ----------------------------------------------------------------------------
  # Fetcher (Playwright-based web fetcher, fallback for sites that block WebFetch)
  # ----------------------------------------------------------------------------
  fetcherBin = pkgs.writeShellScriptBin "fetcher-mcp" ''
    ${nodeSetup}
    exec npx -y fetcher-mcp "$@"
  '';

  # ----------------------------------------------------------------------------
  # Filesystem
  # ----------------------------------------------------------------------------
  filesystemBin = pkgs.writeShellScriptBin "filesystem-mcp" ''
    exec ${pkgs.mcp-server-filesystem}/bin/mcp-server-filesystem "${homeDir}" "$@"
  '';

  # ----------------------------------------------------------------------------
  # Git
  # ----------------------------------------------------------------------------
  gitBin = pkgs.writeShellScriptBin "git-mcp" ''
    exec ${pkgs.mcp-server-git}/bin/mcp-server-git "$@"
  '';

  # ----------------------------------------------------------------------------
  # GitHub
  # ----------------------------------------------------------------------------
  ghBin = "${config.home.profileDirectory}/bin/gh";
  githubPatFile = assistantSecrets.mcp.github-pat.path;
  githubBin = pkgs.writeShellScriptBin "github-mcp" ''
    if [ -x "${ghBin}" ] && token=$("${ghBin}" auth token 2>/dev/null); then
      export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
    elif [ -f "${githubPatFile}" ]; then
      export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${githubPatFile})"
    fi
    exec ${pkgs.mcp-server-github}/bin/mcp-server-github stdio "$@"
  '';

  # ----------------------------------------------------------------------------
  # GitLab
  # ----------------------------------------------------------------------------
  glabBin = "${config.home.profileDirectory}/bin/glab";
  gitlabToolsets = lib.concatStringsSep "," [
    "branches"
    "issues"
    "labels"
    "merge_requests"
    "pipelines"
    "projects"
    "repositories"
  ];
  gitlabBin = pkgs.writeShellScriptBin "gitlab-mcp" ''
    if [ -x "${glabBin}" ]; then
      host=$("${glabBin}" config get host 2>/dev/null || true)
      if [ -n "$host" ]; then
        token=$("${glabBin}" config get token --host "$host" 2>/dev/null || true)
        if [ -n "$token" ]; then
          export GITLAB_PERSONAL_ACCESS_TOKEN="$token"
          export GITLAB_API_URL="https://''${host}/api/v4"
        fi
      fi
    fi
    export GITLAB_TOOLSETS="${gitlabToolsets}"
    exec ${pkgs.mcp-server-gitlab}/bin/mcp-server-gitlab "$@"
  '';
in
{
  inherit (assistantSecrets) mcp;

  # ----------------------------------------------------------------------------
  # MCP servers
  # ----------------------------------------------------------------------------
  servers = {
    atlassian = {
      command = "${atlassianBin}/bin/atlassian-mcp";
      type = "stdio";
    };

    braveSearch = {
      command = "${braveSearchBin}/bin/brave-search-mcp";
      type = "stdio";
    };

    codex = {
      command = "${codexBin}/bin/codex-mcp";
      type = "stdio";
    };

    context7 = {
      command = "${context7Bin}/bin/context7-mcp";
      type = "stdio";
    };

    deepwiki = {
      command = "${deepwikiBin}/bin/deepwiki-mcp";
      type = "stdio";
    };

    fetcher = {
      command = "${fetcherBin}/bin/fetcher-mcp";
      type = "stdio";
      # Playwright downloads browser binaries on first launch.
      startupTimeoutSec = 60;
    };

    filesystem = {
      command = "${filesystemBin}/bin/filesystem-mcp";
      type = "stdio";
    };

    git = {
      command = "${gitBin}/bin/git-mcp";
      type = "stdio";
    };

    github = {
      command = "${githubBin}/bin/github-mcp";
      type = "stdio";
    };

    gitlab = {
      command = "${gitlabBin}/bin/gitlab-mcp";
      type = "stdio";
    };
  };
}
