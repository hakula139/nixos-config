# ==============================================================================
# LLM Assistant Permissions
# ==============================================================================

{
  # ----------------------------------------------------------------------------
  # Gates
  # ----------------------------------------------------------------------------
  gates = [
    # --------------------------------------------------------------------------
    # Local / system state
    # --------------------------------------------------------------------------
    {
      argv = [ "rm" ];
      reason = "Irreversible local deletion.";
    }
    {
      argv = [ "sudo" ];
      reason = "Privilege escalation.";
    }
    {
      argv = [ "agenix" ];
      reason = "Rewrites encrypted secrets.";
    }
    {
      argv = [ "darwin-rebuild" ];
      reason = "Switches system configuration.";
    }
    {
      argv = [ "nixos-rebuild" ];
      reason = "Switches system configuration.";
    }

    # --------------------------------------------------------------------------
    # Shared remote
    # --------------------------------------------------------------------------
    {
      argv = [
        "git"
        "push"
      ];
      reason = "Publishes commits to a remote.";
    }
    {
      argv = [
        "gh"
        "issue"
        "create"
      ];
      reason = "Opens an issue under our identity.";
    }
    {
      argv = [
        "gh"
        "pr"
        "create"
      ];
      reason = "Opens a pull request under our identity.";
    }
    {
      argv = [
        "gh"
        "pr"
        "merge"
      ];
      reason = "Integrates a pull request into a shared branch.";
    }
    {
      argv = [
        "gh"
        "pr"
        "review"
      ];
      reason = "Records a review verdict under our identity.";
    }
    {
      argv = [
        "gh"
        "repo"
        "create"
      ];
      reason = "Creates a repository under our identity.";
    }
    {
      argv = [
        "gh"
        "repo"
        "fork"
      ];
      reason = "Forks a repository under our identity.";
    }
    {
      argv = [
        "glab"
        "issue"
        "create"
      ];
      reason = "Opens an issue under our identity.";
    }
    {
      argv = [
        "glab"
        "mr"
        "create"
      ];
      reason = "Opens a merge request under our identity.";
    }
    {
      argv = [
        "glab"
        "mr"
        "merge"
      ];
      reason = "Integrates a merge request into a shared branch.";
    }
    {
      argv = [
        "glab"
        "mr"
        "approve"
      ];
      reason = "Records an approval under our identity.";
    }
    {
      argv = [
        "glab"
        "repo"
        "create"
      ];
      reason = "Creates a repository under our identity.";
    }
    {
      argv = [
        "glab"
        "repo"
        "fork"
      ];
      reason = "Forks a repository under our identity.";
    }
  ];

  # ----------------------------------------------------------------------------
  # Denies
  # ----------------------------------------------------------------------------
  denies = [
    {
      argv = [
        "agenix"
        "-r"
      ];
      reason = "agenix -r empties every secret when stdin is not a TTY.";
    }
    {
      argv = [
        "agenix"
        "--rekey"
      ];
      reason = "agenix --rekey empties every secret when stdin is not a TTY.";
    }
  ];

  # ----------------------------------------------------------------------------
  # Soft denies
  # ----------------------------------------------------------------------------
  softDenies = [
    {
      name = "GitHub / GitLab writes";
      reason = "Any operation that changes remote state, including Git pushes, CLI commands, MCP tools, and direct API requests.";
    }
  ];
}
