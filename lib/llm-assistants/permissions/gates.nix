# ==================================================================================================
# LLM Assistant Permission Gates
# ==================================================================================================

{
  commands = [
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
      command = "gh pr review";
      reason = "Submits a pull request review, which can approve on the user's behalf.";
    }
    {
      command = "glab mr approve";
      reason = "Approves a merge request on the user's behalf.";
    }
    {
      command = "glab mr merge";
      reason = "Integrates a merge request into a shared branch.";
    }
  ];

  mcp = {
    github = [
      {
        tool = "merge_pull_request";
        reason = "Integrates a pull request into a shared branch.";
      }
      {
        tool = "pull_request_review_write";
        reason = "Submits pull request reviews, which can approve on the user's behalf.";
      }
    ];
    gitlab = [
      {
        tool = "approve_merge_request";
        reason = "Approves a merge request on the user's behalf.";
      }
      {
        tool = "merge_merge_request";
        reason = "Integrates a merge request into a shared branch.";
      }
    ];
    scrapling = [
      {
        tool = "browser_fetch_once";
        reason = "Can launch any browser executable or attach to any CDP endpoint.";
      }
      {
        tool = "browser_open";
        reason = "Can launch any browser executable or attach to any CDP endpoint.";
      }
    ];
  };

  policies = [
    {
      name = "PR / MR merges and approvals";
      reason = ''
        Merging or approving GitHub pull requests or GitLab merge requests through any tool or
        API, including enabling automatic or queued merging and submitting a GitHub review with
        the `APPROVE` event, such as through `pull_request_review_write`. Reviews that only
        comment or request changes don't count as approvals.
      '';
    }
    {
      name = "Shell edits to repository files";
      reason = ''
        Shell commands that create, overwrite, or modify a repository's source or documentation
        files, such as heredoc, `echo`, or `printf` redirects, `tee`, `sed -i`, `perl -i`, and
        Python or other scripts that write files. These changes go through the assistant's
        file-edit tools, which run the formatting and comment-check hooks. This rule does not
        cover generated files, scratch files, files under /tmp, gitignored build output, files
        outside a repository, Git operations, or formatters and code generators that rewrite
        files by their own rules.
      '';
    }
  ];
}
