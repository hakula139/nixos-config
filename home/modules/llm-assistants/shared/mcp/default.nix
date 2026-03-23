{
  config,
  pkgs,
  lib,
  secrets,
  isNixOS ? false,
  ...
}:

# ==============================================================================
# MCP (Model Context Protocol) Configuration
# ==============================================================================

let
  homeDir = config.home.homeDirectory;
  secretsDir = secrets.secretsPath homeDir;

  # ----------------------------------------------------------------------------
  # Brave Search
  # ----------------------------------------------------------------------------
  braveApiKeyFile = "${secretsDir}/brave-api-key";
  braveSearchBin = pkgs.writeShellScriptBin "brave-search-mcp" ''
    export PATH="${pkgs.nodejs}/bin:$PATH"
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
  context7ApiKeyFile = "${secretsDir}/context7-api-key";
  context7Bin = pkgs.writeShellScriptBin "context7-mcp" ''
    export PATH="${pkgs.nodejs}/bin:$PATH"
    if [ -f "${context7ApiKeyFile}" ]; then
      export CONTEXT7_API_KEY="$(cat ${context7ApiKeyFile})"
    fi
    exec npx -y @upstash/context7-mcp "$@"
  '';

  # ----------------------------------------------------------------------------
  # DeepWiki
  # ----------------------------------------------------------------------------
  deepwikiBin = pkgs.writeShellScriptBin "deepwiki-mcp" ''
    export PATH="${pkgs.nodejs}/bin:$PATH"
    exec npx -y mcp-remote https://mcp.deepwiki.com/mcp --transport http-first "$@"
  '';

  # ----------------------------------------------------------------------------
  # Fetcher (Playwright-based web fetcher, fallback for sites that block WebFetch)
  # ----------------------------------------------------------------------------
  fetcherBin = pkgs.writeShellScriptBin "fetcher-mcp" ''
    export PATH="${pkgs.nodejs}/bin:$PATH"
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
  githubPatFile = "${secretsDir}/github-pat";
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
  gitlabBin = pkgs.writeShellScriptBin "gitlab-mcp" ''
    exec "${config.home.profileDirectory}/bin/glab" mcp serve "$@"
  '';
in
{
  # ----------------------------------------------------------------------------
  # MCP servers
  # ----------------------------------------------------------------------------
  servers = {
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

  # ----------------------------------------------------------------------------
  # Secrets
  # ----------------------------------------------------------------------------
  secrets = lib.mkIf (!isNixOS) {
    age.secrets = {
      brave-api-key = secrets.mkHomeSecret {
        name = "brave-api-key";
        inherit homeDir;
      };

      context7-api-key = secrets.mkHomeSecret {
        name = "context7-api-key";
        inherit homeDir;
      };

      github-pat = secrets.mkHomeSecret {
        name = "github-pat-personal";
        inherit homeDir;
        path = "${secretsDir}/github-pat";
      };
    };
  };
}
