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
    # Pull / merge requests
    # --------------------------------------------------------------------------
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
        "glab"
        "mr"
        "merge"
      ];
      reason = "Integrates a merge request into a shared branch.";
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
  # Allows
  # ----------------------------------------------------------------------------
  allows = [
    {
      name = "GitHub / GitLab remote changes";
      reason = "Remote changes are allowed without separate user approval, including pushing commits and creating or updating pull requests. Merging PRs or MRs, including automatic or queued merging, still requires explicit user approval.";
    }
  ];

  # ----------------------------------------------------------------------------
  # Soft denies
  # ----------------------------------------------------------------------------
  softDenies = [
    {
      name = "PR / MR merges";
      reason = "Merging GitHub pull requests or GitLab merge requests through any tool or API, including enabling automatic or queued merging.";
    }
  ];
}
