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
    if [ -f "${braveApiKeyFile}" ]; then
      export BRAVE_API_KEY="$(cat ${braveApiKeyFile})"
    fi
    exec ${pkgs.nodejs}/bin/npx -y @brave/brave-search-mcp-server "$@"
  '';

  # ----------------------------------------------------------------------------
  # Context7
  # ----------------------------------------------------------------------------
  context7ApiKeyFile = "${secretsDir}/context7-api-key";
  context7Bin = pkgs.writeShellScriptBin "context7-mcp" ''
    if [ -f "${context7ApiKeyFile}" ]; then
      export CONTEXT7_API_KEY="$(cat ${context7ApiKeyFile})"
    fi
    exec ${pkgs.nodejs}/bin/npx -y @upstash/context7-mcp "$@"
  '';

  # ----------------------------------------------------------------------------
  # DeepWiki
  # ----------------------------------------------------------------------------
  deepwikiBin = pkgs.writeShellScriptBin "deepwiki-mcp" ''
    exec ${pkgs.nodejs}/bin/npx -y mcp-remote https://mcp.deepwiki.com/mcp --transport http-first "$@"
  '';

  # ----------------------------------------------------------------------------
  # Filesystem
  # ----------------------------------------------------------------------------
  filesystemBin = pkgs.writeShellScriptBin "filesystem-mcp" ''
    exec ${pkgs.nodejs}/bin/npx -y @modelcontextprotocol/server-filesystem "${homeDir}" "$@"
  '';

  # ----------------------------------------------------------------------------
  # Git
  # ----------------------------------------------------------------------------
  gitBin = pkgs.writeShellScriptBin "git-mcp" ''
    exec ${pkgs.uv}/bin/uvx mcp-server-git "$@"
  '';

  # ----------------------------------------------------------------------------
  # GitHub
  # ----------------------------------------------------------------------------
  githubPatFile = "${secretsDir}/github-pat";
  githubBin = pkgs.writeShellScriptBin "github-mcp" ''
    if [ -f "${githubPatFile}" ]; then
      export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${githubPatFile})"
    fi
    exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio "$@"
  '';
in
{
  # ----------------------------------------------------------------------------
  # MCP servers
  # ----------------------------------------------------------------------------
  servers = {
    braveSearch = {
      name = "BraveSearch";
      command = "${braveSearchBin}/bin/brave-search-mcp";
      type = "stdio";
    };

    context7 = {
      name = "Context7";
      command = "${context7Bin}/bin/context7-mcp";
      type = "stdio";
    };

    deepwiki = {
      name = "DeepWiki";
      command = "${deepwikiBin}/bin/deepwiki-mcp";
      type = "stdio";
    };

    filesystem = {
      name = "Filesystem";
      command = "${filesystemBin}/bin/filesystem-mcp";
      type = "stdio";
    };

    git = {
      name = "Git";
      command = "${gitBin}/bin/git-mcp";
      type = "stdio";
    };

    github = {
      name = "GitHub";
      command = "${githubBin}/bin/github-mcp";
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
        name = "github-pat";
        inherit homeDir;
      };
    };
  };
}
