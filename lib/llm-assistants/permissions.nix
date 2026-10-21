# ==================================================================================================
# LLM Assistant Permissions
# ==================================================================================================

{
  # ------------------------------------------------------------------------------------------------
  # Gates
  # ------------------------------------------------------------------------------------------------
  gates = {
    commands = [
      # --------------------------------------------------------------------------------------------
      # Local / system state
      # --------------------------------------------------------------------------------------------
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

      # --------------------------------------------------------------------------------------------
      # Host activation
      # --------------------------------------------------------------------------------------------
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

      # --------------------------------------------------------------------------------------------
      # Pull / merge requests
      # --------------------------------------------------------------------------------------------
      {
        command = "gh pr merge";
        reason = "Integrates a pull request into a shared branch.";
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
      ];
      gitlab = [
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
        name = "PR / MR merges";
        reason = ''
          Merging GitHub pull requests or GitLab merge requests through any tool or API,
          including enabling automatic or queued merging.
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
  };

  # ------------------------------------------------------------------------------------------------
  # Allows
  # ------------------------------------------------------------------------------------------------
  allows = {
    commands = {
      # Reads local or remote state. No flag writes files, changes remote or system state, or starts
      # another program. Nix store and cache writes don't count.
      readOnly = [
        # ------------------------------------------------------------------------------------------
        # Filesystem - Navigation
        # ------------------------------------------------------------------------------------------
        "cd"
        "eza"
        "ls"
        "pwd"

        # ------------------------------------------------------------------------------------------
        # Filesystem - Reading
        # ------------------------------------------------------------------------------------------
        "cat"
        "head"
        "readelf"
        "stat"
        "tail"

        # ------------------------------------------------------------------------------------------
        # Filesystem - Search
        # ------------------------------------------------------------------------------------------
        "grep"

        # ------------------------------------------------------------------------------------------
        # Text Processing
        # ------------------------------------------------------------------------------------------
        "col"
        "cut"
        "diff"
        "jq"
        "tr"
        "wc"

        # ------------------------------------------------------------------------------------------
        # Shell
        # ------------------------------------------------------------------------------------------
        "basename"
        "command -v"
        "dirname"
        "echo"
        "false"
        "printf"
        "readlink"
        "realpath"
        "sleep"
        "test"
        "true"
        "type"
        "whereis"
        "which"

        # ------------------------------------------------------------------------------------------
        # System
        # ------------------------------------------------------------------------------------------
        "date"
        "df"
        "du"
        "free"
        "hostname"
        "id"
        "lsof"
        "pgrep"
        "ps"
        "top"
        "uname"
        "uptime"
        "whoami"

        # ------------------------------------------------------------------------------------------
        # systemd
        # ------------------------------------------------------------------------------------------
        "hostnamectl status"
        "localectl status"
        "loginctl list-seats"
        "loginctl list-sessions"
        "loginctl list-users"
        "loginctl session-status"
        "loginctl show-seat"
        "loginctl show-session"
        "loginctl show-user"
        "loginctl user-status"
        "systemctl --user is-active"
        "systemctl --user is-enabled"
        "systemctl --user is-failed"
        "systemctl --user is-system-running"
        "systemctl --user list-automounts"
        "systemctl --user list-dependencies"
        "systemctl --user list-jobs"
        "systemctl --user list-machines"
        "systemctl --user list-paths"
        "systemctl --user list-sockets"
        "systemctl --user list-timers"
        "systemctl --user list-unit-files"
        "systemctl --user list-units"
        "systemctl --user show"
        "systemctl --user status"
        "systemctl is-active"
        "systemctl is-enabled"
        "systemctl is-failed"
        "systemctl is-system-running"
        "systemctl list-automounts"
        "systemctl list-dependencies"
        "systemctl list-jobs"
        "systemctl list-machines"
        "systemctl list-paths"
        "systemctl list-sockets"
        "systemctl list-timers"
        "systemctl list-unit-files"
        "systemctl list-units"
        "systemctl show"
        "systemctl status"
        "timedatectl show"
        "timedatectl status"
        "timedatectl timesync-status"

        # ------------------------------------------------------------------------------------------
        # Network
        # ------------------------------------------------------------------------------------------
        "dig"
        "host"
        "nslookup"
        "ping"
        "whois"

        # ------------------------------------------------------------------------------------------
        # macOS
        # ------------------------------------------------------------------------------------------
        "launchctl list"
        "pbpaste"
        "sw_vers"

        # ------------------------------------------------------------------------------------------
        # Git
        # ------------------------------------------------------------------------------------------
        "git blame"
        "git cat-file"
        "git check-ignore"
        "git describe"
        "git for-each-ref"
        "git ls-files"
        "git ls-tree"
        "git merge-base"
        "git name-rev"
        "git rev-list"
        "git rev-parse"
        "git shortlog"
        "git status"
        "git worktree list"

        # ------------------------------------------------------------------------------------------
        # GitHub / GitLab
        # ------------------------------------------------------------------------------------------
        "gh issue view"
        "gh label list"
        "gh pr checks"
        "gh pr diff"
        "gh pr list"
        "gh pr view"
        "gh release list"
        "gh release view"
        "gh repo view"
        "gh run list"
        "gh run view"
        "gh run watch"
        "gh search code"
        "gh search issues"
        "glab ci list"
        "glab ci status"
        "glab ci trace"
        "glab issue list"
        "glab issue view"
        "glab label list"
        "glab mr list"
        "glab mr view"

        # ------------------------------------------------------------------------------------------
        # Development
        # ------------------------------------------------------------------------------------------
        "npm config get"
        "npm view"
        "shellcheck"

        # ------------------------------------------------------------------------------------------
        # Nix
        # ------------------------------------------------------------------------------------------
        "nix derivation show"
        "nix flake info"
        "nix hash"
        "nix help"
        "nix log"
        "nix path-info"
        "nix print-dev-env"
        "nix search"
        "nix store ls"
        "nix store path-info"
        "nix why-depends"
        "nix-store --query"
        "nix-store -q"
        "nix-tree"
        "nvd"

        # ------------------------------------------------------------------------------------------
        # Containers
        # ------------------------------------------------------------------------------------------
        "docker compose logs"
        "docker compose ls"
        "docker compose ps"
        "docker context ls"
        "docker image inspect"
        "docker image ls"
        "docker images"
        "docker info"
        "docker inspect"
        "docker logs"
        "docker manifest inspect"
        "docker network inspect"
        "docker ps"
        "docker version"
        "docker volume ls"
        "helm dependency list"
        "helm env"
        "helm get"
        "helm history"
        "helm lint"
        "helm list"
        "helm plugin list"
        "helm repo list"
        "helm search"
        "helm show"
        "helm status"
        "helm verify"
        "helm version"
        "kubectl api-resources"
        "kubectl explain"
        "kubectl logs"
        "kubectl version"
        "podman compose logs"
        "podman compose ls"
        "podman compose ps"
        "podman images"
        "podman info"
        "podman inspect"
        "podman logs"
        "podman ps"
        "podman version"
      ];

      # Needs no approval where a sandbox or classifier contains it, but may write files, change
      # remote or system state, start another program, or reveal secrets.
      mutating = [
        # ------------------------------------------------------------------------------------------
        # General
        # ------------------------------------------------------------------------------------------
        "man"

        # ------------------------------------------------------------------------------------------
        # Filesystem - Navigation
        # ------------------------------------------------------------------------------------------
        "tree"

        # ------------------------------------------------------------------------------------------
        # Filesystem - Reading
        # ------------------------------------------------------------------------------------------
        "bat"
        "file"
        "ldd"
        "less"
        "more"
        "pdftotext"

        # ------------------------------------------------------------------------------------------
        # Filesystem - Search
        # ------------------------------------------------------------------------------------------
        "rg"

        # ------------------------------------------------------------------------------------------
        # Filesystem - Modification
        # ------------------------------------------------------------------------------------------
        "cp"
        "ln"
        "mkdir"
        "mv"
        "touch"

        # ------------------------------------------------------------------------------------------
        # Filesystem - Archive
        # ------------------------------------------------------------------------------------------
        "7z"
        "gunzip"
        "gzip"
        "tar"
        "unzip"
        "zip"
        "zstd"

        # ------------------------------------------------------------------------------------------
        # Text Processing
        # ------------------------------------------------------------------------------------------
        "sort"
        "uniq"
        "yq"

        # ------------------------------------------------------------------------------------------
        # System
        # ------------------------------------------------------------------------------------------
        "journalctl"

        # ------------------------------------------------------------------------------------------
        # systemd
        # ------------------------------------------------------------------------------------------
        "busctl"
        "networkctl"
        "resolvectl"

        # ------------------------------------------------------------------------------------------
        # Network
        # ------------------------------------------------------------------------------------------
        "ip"
        "ss"

        # ------------------------------------------------------------------------------------------
        # macOS
        # ------------------------------------------------------------------------------------------
        "open"
        "pbcopy"

        # ------------------------------------------------------------------------------------------
        # Git
        # ------------------------------------------------------------------------------------------
        "git add"
        "git branch"
        "git diff"
        "git fetch"
        "git grep"
        "git log"
        "git ls-remote"
        "git remote"
        "git show"
        "git stash"
        "git switch"
        "git tag"
        "git worktree add"
        "git worktree remove"

        # ------------------------------------------------------------------------------------------
        # GitHub / GitLab
        # ------------------------------------------------------------------------------------------
        "gh auth status"

        # ------------------------------------------------------------------------------------------
        # Development
        # ------------------------------------------------------------------------------------------
        "cargo"
        "cspell"
        "g++"
        "gcc"
        "markdownlint-cli2"
        "pnpm exec cspell"
        "pnpm exec prettier"
        "ruff"
        "rustc"
        "shfmt"
        "uv lock"
        "uv run ruff"
        "uv sync"

        # ------------------------------------------------------------------------------------------
        # Nix
        # ------------------------------------------------------------------------------------------
        "deadnix"
        "nix build"
        "nix develop -c cargo"
        "nix develop -c true"
        "nix eval"
        "nix flake archive"
        "nix flake check"
        "nix flake metadata"
        "nix flake show"
        "nix repl"
        "nix-build"
        "nix-instantiate"
        "nix-prefetch-url"
        "nixfmt"
        "statix"

        # ------------------------------------------------------------------------------------------
        # Containers
        # ------------------------------------------------------------------------------------------
        "docker compose config"
        "helm template"
        "kubectl config"
        "kubectl describe"
        "kubectl get"
        "podman compose config"
      ];
    };

    mcp = {
      atlassian = [
        "confluence_check_content_permissions"
        "confluence_download_attachment"
        "confluence_download_content_attachments"
        "confluence_get_attachments"
        "confluence_get_comments"
        "confluence_get_inline_comments"
        "confluence_get_labels"
        "confluence_get_page"
        "confluence_get_page_children"
        "confluence_get_page_diff"
        "confluence_get_page_history"
        "confluence_get_page_images"
        "confluence_get_page_restrictions"
        "confluence_get_page_template"
        "confluence_get_page_views"
        "confluence_get_space_page_tree"
        "confluence_get_space_permissions"
        "confluence_list_page_templates"
        "confluence_search"
        "confluence_search_user"
      ];
      bifrost = [
        "SearXNG-searxng_instance_info"
        "SearXNG-searxng_search_suggestions"
        "SearXNG-searxng_web_search"
        "SearXNG-web_url_read"
        "exa-web_fetch_exa"
        "exa-web_search_exa"
        "you-you-search"
      ];
      deepwiki = [
        "ask_wiki_question"
        "read_wiki_contents"
        "read_wiki_structure"
      ];
      exa = [
        "web_fetch_exa"
        "web_search_advanced_exa"
        "web_search_exa"
      ];
      github = [
        "get_commit"
        "get_file_contents"
        "get_label"
        "get_latest_release"
        "get_me"
        "get_release_by_tag"
        "get_tag"
        "get_team_members"
        "get_teams"
        "issue_read"
        "list_branches"
        "list_commits"
        "list_issue_fields"
        "list_issue_types"
        "list_issues"
        "list_pull_requests"
        "list_releases"
        "list_repository_collaborators"
        "list_tags"
        "pull_request_read"
        "search_code"
        "search_commits"
        "search_issues"
        "search_pull_requests"
        "search_repositories"
        "search_users"
      ];
      gitlab = [
        "get_branch"
        "get_branch_diffs"
        "get_commit"
        "get_commit_diff"
        "get_deployment"
        "get_draft_note"
        "get_environment"
        "get_file_blame"
        "get_file_contents"
        "get_issue"
        "get_issue_link"
        "get_job_artifact_file"
        "get_label"
        "get_merge_request"
        "get_merge_request_approval_state"
        "get_merge_request_conflicts"
        "get_merge_request_diffs"
        "get_merge_request_file_diff"
        "get_merge_request_note"
        "get_merge_request_notes"
        "get_merge_request_version"
        "get_namespace"
        "get_pipeline"
        "get_pipeline_job"
        "get_pipeline_job_output"
        "get_project"
        "get_protected_branch"
        "get_repository_tree"
        "health_check"
        "list_branches"
        "list_commit_statuses"
        "list_commits"
        "list_deployments"
        "list_draft_notes"
        "list_environments"
        "list_group_iterations"
        "list_group_members"
        "list_group_projects"
        "list_issue_discussions"
        "list_issue_emoji_reactions"
        "list_issue_links"
        "list_issue_note_emoji_reactions"
        "list_issues"
        "list_job_artifacts"
        "list_labels"
        "list_merge_request_changed_files"
        "list_merge_request_diffs"
        "list_merge_request_emoji_reactions"
        "list_merge_request_note_emoji_reactions"
        "list_merge_request_pipelines"
        "list_merge_request_versions"
        "list_merge_requests"
        "list_namespaces"
        "list_pipeline_jobs"
        "list_pipeline_trigger_jobs"
        "list_pipelines"
        "list_project_members"
        "list_projects"
        "list_protected_branches"
        "list_todos"
        "mr_discussions"
        "my_issues"
        "search_repositories"
        "verify_namespace"
      ];
    };

    tools = [
      "webFetch"
      "webSearch"
    ];

    paths = [ "/tmp" ];

    policies = [
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
  };
}
