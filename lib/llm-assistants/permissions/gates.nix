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

  # Arguments that make a command run another program. An argument starting with `-` matches
  # anywhere after the command, and any other argument matches as its own word. Patterns can't
  # follow abbreviated long options or combined short options, so a command whose parser accepts
  # either has no allow.
  arguments = [
    {
      commands = [ "bat" ];
      arguments = [ "--pager" ];
      reason = "Runs the given program as a pager.";
    }
    {
      commands = [ "busctl" ];
      arguments = [ "call" ];
      reason = "Calls any D-Bus method, including starting a transient unit.";
    }
    {
      commands = [
        "git fetch"
        "git ls-remote"
      ];
      arguments = [ "--upload-pack" ];
      reason = "Runs the given program in place of git-upload-pack.";
    }
    {
      commands = [ "git grep" ];
      arguments = [
        "--open-files-in-pager"
        "-O"
      ];
      reason = "Opens the matching files in the given program.";
    }
    {
      commands = [
        "helm get"
        "helm history"
        "helm list"
        "helm status"
        "helm template"
        "kubectl api-resources"
        "kubectl describe"
        "kubectl explain"
        "kubectl get"
        "kubectl logs"
        "kubectl version"
      ];
      arguments = [ "--kubeconfig" ];
      reason = "Runs the exec credential plugin named in the given kubeconfig.";
    }
    {
      commands = [ "helm template" ];
      arguments = [ "--post-renderer" ];
      reason = "Runs the given program on the rendered manifests.";
    }
    {
      commands = [ "man" ];
      arguments = [
        "--html"
        "--pager"
        "-H"
        "-P"
      ];
      reason = "Runs the given program as a pager or browser.";
    }
    {
      commands = [
        "nix build"
        "nix derivation show"
        "nix develop"
        "nix eval"
        "nix flake"
        "nix log"
        "nix path-info"
        "nix print-dev-env"
        "nix repl"
        "nix search"
        "nix why-depends"
        "nix-build"
        "nix-instantiate"
      ];
      arguments = [
        "--allow-unsafe-native-code-during-evaluation"
        "--build-hook"
        "--diff-hook"
        "--option"
        "--post-build-hook"
        "--pre-build-hook"
      ];
      reason = "Lets evaluation or the build hooks run arbitrary programs.";
    }
    {
      commands = [ "pnpm exec prettier" ];
      arguments = [ "--plugin" ];
      reason = "Loads the given JavaScript module.";
    }
    {
      commands = [ "rg" ];
      arguments = [
        "--hostname-bin"
        "--pre"
      ];
      reason = "Runs the given program on each searched file or to look up the hostname.";
    }
    {
      commands = [ "sort" ];
      arguments = [ "--compress-program" ];
      reason = "Runs the given program to compress temporary files.";
    }
    {
      commands = [ "tar" ];
      arguments = [
        "--checkpoint-action"
        "--info-script"
        "--new-volume-script"
        "--rmt-command"
        "--rsh-command"
        "--to-command"
        "--use-compress-program"
        "-F"
        "-I"
      ];
      reason = "Runs the given program while reading or writing the archive.";
    }
    {
      commands = [ "zip" ];
      arguments = [
        "--unzip-command"
        "-TT"
      ];
      reason = "Runs the given program to test the archive.";
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
        file-edit tools, which run the edit hooks for prose polish, formatting, and comment
        checks. This rule does not cover generated files, scratch files, files under /tmp,
        gitignored build output, files outside a repository, Git operations, formatters and code
        generators that rewrite files by their own rules, or restoring text an edit hook dropped.
      '';
    }
  ];
}
