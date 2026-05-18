# ==============================================================================
# MCP (Model Context Protocol) Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpDomain,
  proxyLib,
  secretPath,
  ...
}:

let
  homeDir = config.home.homeDirectory;

  # undici (Node's built-in fetch) needs --use-env-proxy to honour HTTP_PROXY.
  nodejs = pkgs.nodejs_24;
  nodeSetup = ''
    export PATH="${nodejs}/bin:$PATH"
    export NODE_OPTIONS="''${NODE_OPTIONS:+$NODE_OPTIONS }--use-env-proxy"
  '';

  exportFromFile = var: file: ''
    if [ -f "${file}" ]; then
      export ${var}="$(cat ${file})"
    fi
  '';

  # Wrapper for `npx -y <package>` style MCP servers, sharing nodeSetup + env exports + exec.
  mkNpmServer =
    {
      name,
      package,
      env ? { },
      extraArgs ? [ ],
    }:
    pkgs.writeShellScriptBin "${name}-mcp" (
      let
        exports = lib.concatStrings (lib.mapAttrsToList exportFromFile env);
        argLine = lib.concatStringsSep " " ([ "npx -y ${package}" ] ++ extraArgs ++ [ ''"$@"'' ]);
      in
      ''
        ${nodeSetup}
        ${exports}
        exec ${argLine}
      ''
    );

  # ----------------------------------------------------------------------------
  # Atlassian (Confluence)
  # ----------------------------------------------------------------------------
  confluencePatFile = secretPath "confluence-pat";
  atlassianBin = pkgs.writeShellScriptBin "atlassian-mcp" ''
    export PATH="${pkgs.uv}/bin:$PATH"
    ${exportFromFile "CONFLUENCE_PERSONAL_TOKEN" confluencePatFile}
    export CONFLUENCE_URL="https://wiki.${corpDomain}"
    # mcp-atlassian honours HTTP_PROXY but ignores NO_PROXY, so unset proxies for internal Confluence.
    ${proxyLib.clearProxyEnv}
    exec uvx mcp-atlassian "$@"
  '';

  # ----------------------------------------------------------------------------
  # Brave Search
  # ----------------------------------------------------------------------------
  braveSearchBin = mkNpmServer {
    name = "brave-search";
    package = "@brave/brave-search-mcp-server";
    env.BRAVE_API_KEY = secretPath "brave-api-key";
  };

  # ----------------------------------------------------------------------------
  # Codex
  # ----------------------------------------------------------------------------
  codexBin = pkgs.writeShellScriptBin "codex-mcp" ''
    exec "${config.home.profileDirectory}/bin/codex" mcp-server "$@"
  '';

  # ----------------------------------------------------------------------------
  # Context7
  # ----------------------------------------------------------------------------
  context7Bin = mkNpmServer {
    name = "context7";
    package = "@upstash/context7-mcp";
    env.CONTEXT7_API_KEY = secretPath "context7-api-key";
  };

  # ----------------------------------------------------------------------------
  # DeepWiki
  # ----------------------------------------------------------------------------
  deepwikiBin = mkNpmServer {
    name = "deepwiki";
    package = "mcp-remote";
    extraArgs = [
      "https://mcp.deepwiki.com/mcp"
      "--transport"
      "http-first"
    ];
  };

  # ----------------------------------------------------------------------------
  # Fetcher
  # ----------------------------------------------------------------------------
  fetcherBin = mkNpmServer {
    name = "fetcher";
    package = "fetcher-mcp";
  };

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
  githubPatFile = secretPath "github-pat";
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
