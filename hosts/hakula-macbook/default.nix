# ==============================================================================
# hakula-macbook Darwin Configuration
# ==============================================================================

{
  pkgs,
  keys,
  hostName,
  displayName,
  ...
}:

{
  imports = [
    ../../modules/darwin
  ];

  # ----------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------
  networking = {
    inherit hostName;
    computerName = displayName;
    localHostName = hostName;
  };

  # ----------------------------------------------------------------------------
  # Access (SSH)
  # ----------------------------------------------------------------------------
  hakula.access.ssh.authorizedKeys = with keys.workstations; [
    hakula-macbook
    hakula-work
  ];

  # ----------------------------------------------------------------------------
  # Credentials
  # ----------------------------------------------------------------------------
  hakula.cachix.enable = true;

  # ----------------------------------------------------------------------------
  # Assistant Tooling
  # ----------------------------------------------------------------------------
  hakula.llm-assistants = {
    enable = true;
    proxy.enable = true;
  };

  # ----------------------------------------------------------------------------
  # Packages
  # ----------------------------------------------------------------------------
  environment.systemPackages = [ pkgs.peertube.runner ];

  # ----------------------------------------------------------------------------
  # Services
  # ----------------------------------------------------------------------------
  hakula.services.openssh.enable = true;
  hakula.services.tailscale = {
    enable = true;
    userspaceNetworking = true;
  };

  # ----------------------------------------------------------------------------
  # Home Manager Overrides
  # ----------------------------------------------------------------------------
  home-manager.users.hakula = {
    hakula.claude-code.mcp.enabledServers = [
      "codex"
      "deepwiki"
      "fetcher"
      "filesystem"
      "git"
      "github"
    ];
    hakula.codex.mcp.enabledServers = [
      "context7"
      "deepwiki"
      "fetcher"
      "filesystem"
      "git"
      "github"
    ];
    hakula.cursor = {
      mcp.enabledServers = [
        "deepwiki"
        "fetcher"
        "filesystem"
        "git"
        "github"
      ];
      nixd.flakePath = "/Users/hakula/GitHub/nixos-config";
    };
  };

  # ----------------------------------------------------------------------------
  # System State
  # ----------------------------------------------------------------------------
  system.stateVersion = 6;
}
