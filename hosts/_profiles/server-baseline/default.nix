# ==============================================================================
# Server Baseline Profile
# ==============================================================================

{
  config,
  lib,
  ...
}:

{
  # ----------------------------------------------------------------------------
  # Distributed Builds
  # ----------------------------------------------------------------------------
  hakula.builders.enable = true;

  # ----------------------------------------------------------------------------
  # Credentials
  # ----------------------------------------------------------------------------
  hakula.cachix.enable = true;

  # ----------------------------------------------------------------------------
  # Assistant Tooling
  # ----------------------------------------------------------------------------
  hakula.llm-assistants.enable = lib.mkDefault true;

  home-manager.users.${config.hakula.user.name} = {
    hakula.claude-code.mcp.enabledServers = lib.mkDefault [
      "codex"
      "deepwiki"
      "fetcher"
      "filesystem"
      "git"
      "github"
    ];
    hakula.codex.mcp.enabledServers = lib.mkDefault [
      "context7"
      "deepwiki"
      "fetcher"
      "filesystem"
      "git"
      "github"
    ];
  };

  # ----------------------------------------------------------------------------
  # Services
  # ----------------------------------------------------------------------------
  hakula.services.netdata.enable = true;
  hakula.services.nginx.enable = true;
  hakula.services.openssh.enable = true;
  hakula.services.xray = {
    enable = true;
    ws.enable = true;
  };
}
