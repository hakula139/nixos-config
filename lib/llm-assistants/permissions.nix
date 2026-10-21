# ==================================================================================================
# LLM Assistant Permissions
# ==================================================================================================

{
  # ------------------------------------------------------------------------------------------------
  # Gates
  # ------------------------------------------------------------------------------------------------
  gates = [
    # ----------------------------------------------------------------------------------------------
    # Local / system state
    # ----------------------------------------------------------------------------------------------
    {
      command = "agenix";
      reason = "Rewrites encrypted secrets.";
    }
    {
      command = "rm";
      reason = "Irreversible local deletion.";
    }
    {
      command = "sudo";
      reason = "Privilege escalation.";
    }

    # ----------------------------------------------------------------------------------------------
    # Host activation
    # ----------------------------------------------------------------------------------------------
    {
      command = "colmena apply";
      reason = "Deploys host configurations.";
    }
    {
      command = "colmena apply-local";
      reason = "Switches system configuration.";
    }
    {
      command = "colmena upload-keys";
      reason = "Deploys secrets to hosts.";
    }
    {
      command = "darwin-rebuild";
      reason = "Switches system configuration.";
    }
    {
      command = "home-manager switch";
      reason = "Switches home configuration.";
    }
    {
      command = "nh darwin switch";
      reason = "Switches system configuration.";
    }
    {
      command = "nh home switch";
      reason = "Switches home configuration.";
    }
    {
      command = "nh os boot";
      reason = "Changes the boot configuration.";
    }
    {
      command = "nh os rollback";
      reason = "Switches system configuration.";
    }
    {
      command = "nh os switch";
      reason = "Switches system configuration.";
    }
    {
      command = "nh os test";
      reason = "Switches system configuration.";
    }
    {
      command = "nixboot";
      reason = "Changes the boot configuration.";
    }
    {
      command = "nixdp";
      reason = "Deploys host configurations.";
    }
    {
      command = "nixos-rebuild";
      reason = "Switches system configuration.";
    }
    {
      command = "nixroll";
      reason = "Switches system configuration.";
    }
    {
      command = "nixsw";
      reason = "Switches system configuration.";
    }
    {
      command = "nixtest";
      reason = "Switches system configuration.";
    }
    {
      command = "system-manager activate";
      reason = "Switches system configuration.";
    }
    {
      command = "system-manager deactivate";
      reason = "Removes managed system configuration.";
    }
    {
      command = "system-manager pre-populate";
      reason = "Writes managed system files.";
    }
    {
      command = "system-manager register";
      reason = "Changes the active system profile.";
    }
    {
      command = "system-manager switch";
      reason = "Switches system configuration.";
    }

    # ----------------------------------------------------------------------------------------------
    # Pull / merge requests
    # ----------------------------------------------------------------------------------------------
    {
      command = "gh pr merge";
      reason = "Integrates a pull request into a shared branch.";
    }
    {
      command = "glab mr merge";
      reason = "Integrates a merge request into a shared branch.";
    }
  ];

  # ------------------------------------------------------------------------------------------------
  # Allows
  # ------------------------------------------------------------------------------------------------
  allows = [
    {
      name = "Repository Git configuration";
      reason = ''
        Changing repository-local Git configuration in repositories under github.com/hakula139
        is allowed without separate user approval, including repairing settings that a tool or
        test corrupted.
        Changing global or system Git configuration still requires explicit user approval.
      '';
    }
    {
      name = "GitHub / GitLab remote changes";
      reason = ''
        Remote changes are allowed without separate user approval, including pushing commits
        and creating or updating pull requests.
        Merging PRs or MRs, including automatic or queued merging, still requires
        explicit user approval.
      '';
    }
  ];

  # ------------------------------------------------------------------------------------------------
  # Soft denies
  # ------------------------------------------------------------------------------------------------
  softDenies = [
    {
      name = "PR / MR merges";
      reason = ''
        Merging GitHub pull requests or GitLab merge requests through any tool or API,
        including enabling automatic or queued merging.
      '';
    }
  ];
}
