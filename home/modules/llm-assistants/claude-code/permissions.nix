# ==============================================================================
# Claude Code Permissions
# ==============================================================================

{
  defaultMode = "acceptEdits";

  # ============================================================================
  # Allow - Auto-approved commands (read-only / safe operations)
  # ============================================================================

  allow = [
    # --------------------------------------------------------------------------
    # General
    # --------------------------------------------------------------------------
    "Bash(* --version)"

    # --------------------------------------------------------------------------
    # Documentation
    # --------------------------------------------------------------------------
    "Bash(* --help)"
    "Bash(* --help *)"
    "Bash(man *)"
    "mcp__DeepWiki"
    "mcp__plugin_context7-plugin_context7"

    # --------------------------------------------------------------------------
    # Filesystem - Navigation
    # --------------------------------------------------------------------------
    "Bash(cd *)"
    "Bash(eza *)"
    "Bash(ls *)"
    "Bash(pwd *)"
    "Bash(tree *)"
    "mcp__Filesystem"

    # --------------------------------------------------------------------------
    # Filesystem - Reading
    # --------------------------------------------------------------------------
    "Bash(bat *)"
    "Bash(cat *)"
    "Bash(file *)"
    "Bash(head *)"
    "Bash(ldd *)"
    "Bash(less *)"
    "Bash(more *)"
    "Bash(readelf *)"
    "Bash(stat *)"
    "Bash(tail *)"

    # --------------------------------------------------------------------------
    # Filesystem - Search
    # --------------------------------------------------------------------------
    "Bash(fd *)"
    "Bash(find *)"
    "Bash(grep *)"
    "Bash(rg *)"

    # --------------------------------------------------------------------------
    # Filesystem - Modification
    # --------------------------------------------------------------------------
    "Bash(cp *)"
    "Bash(ln *)"
    "Bash(mkdir *)"
    "Bash(mv *)"
    "Bash(touch *)"

    # --------------------------------------------------------------------------
    # Filesystem - Archive
    # --------------------------------------------------------------------------
    "Bash(7z *)"
    "Bash(gunzip *)"
    "Bash(gzip *)"
    "Bash(tar *)"
    "Bash(unzip *)"
    "Bash(zip *)"
    "Bash(zstd *)"

    # --------------------------------------------------------------------------
    # Text Processing
    # --------------------------------------------------------------------------
    "Bash(awk *)"
    "Bash(col *)"
    "Bash(cut *)"
    "Bash(diff *)"
    "Bash(jq *)"
    "Bash(sed *)"
    "Bash(sort *)"
    "Bash(tee *)"
    "Bash(tr *)"
    "Bash(uniq *)"
    "Bash(wc *)"
    "Bash(xargs *)"
    "Bash(yq *)"

    # --------------------------------------------------------------------------
    # Shell
    # --------------------------------------------------------------------------
    "Bash(basename *)"
    "Bash(command *)"
    "Bash(dirname *)"
    "Bash(echo *)"
    "Bash(env *)"
    "Bash(false *)"
    "Bash(printf *)"
    "Bash(readlink *)"
    "Bash(realpath *)"
    "Bash(test *)"
    "Bash(true *)"
    "Bash(type *)"
    "Bash(whereis *)"
    "Bash(which *)"

    # --------------------------------------------------------------------------
    # System
    # --------------------------------------------------------------------------
    "Bash(date *)"
    "Bash(df *)"
    "Bash(du *)"
    "Bash(free *)"
    "Bash(hostname *)"
    "Bash(id *)"
    "Bash(journalctl *)"
    "Bash(lsof *)"
    "Bash(pgrep *)"
    "Bash(ps *)"
    "Bash(top *)"
    "Bash(uname *)"
    "Bash(uptime *)"
    "Bash(whoami *)"

    # --------------------------------------------------------------------------
    # systemd
    # --------------------------------------------------------------------------
    "Bash(busctl *)"
    "Bash(hostnamectl status *)"
    "Bash(localectl status *)"
    "Bash(loginctl list-*)"
    "Bash(loginctl session-status *)"
    "Bash(loginctl show-*)"
    "Bash(loginctl user-status *)"
    "Bash(networkctl *)"
    "Bash(resolvectl *)"
    "Bash(systemctl --user is-*)"
    "Bash(systemctl --user list-*)"
    "Bash(systemctl --user show *)"
    "Bash(systemctl --user status *)"
    "Bash(systemctl is-*)"
    "Bash(systemctl list-*)"
    "Bash(systemctl show *)"
    "Bash(systemctl status *)"
    "Bash(timedatectl show *)"
    "Bash(timedatectl status *)"
    "Bash(timedatectl timesync-status *)"

    # --------------------------------------------------------------------------
    # Network
    # --------------------------------------------------------------------------
    "Bash(curl *)"
    "Bash(dig *)"
    "Bash(host *)"
    "Bash(http *)"
    "Bash(httpie *)"
    "Bash(https *)"
    "Bash(ip *)"
    "Bash(nc *)"
    "Bash(nslookup *)"
    "Bash(ping *)"
    "Bash(ss *)"
    "Bash(wget *)"
    "Bash(whois *)"
    "mcp__Fetcher"
    "WebFetch"
    "WebSearch"

    # --------------------------------------------------------------------------
    # macOS
    # --------------------------------------------------------------------------
    "Bash(launchctl list *)"
    "Bash(open *)"
    "Bash(pbcopy *)"
    "Bash(pbpaste *)"
    "Bash(sw_vers *)"

    # --------------------------------------------------------------------------
    # Git
    # --------------------------------------------------------------------------
    "Bash(git add *)"
    "Bash(git blame *)"
    "Bash(git branch *)"
    "Bash(git describe *)"
    "Bash(git diff *)"
    "Bash(git fetch *)"
    "Bash(git log *)"
    "Bash(git ls-*)"
    "Bash(git name-rev *)"
    "Bash(git remote *)"
    "Bash(git rev-*)"
    "Bash(git shortlog *)"
    "Bash(git show *)"
    "Bash(git stash *)"
    "Bash(git status *)"
    "Bash(git switch *)"
    "Bash(git tag *)"
    "Bash(git worktree add *)"
    "Bash(git worktree list *)"
    "Bash(git worktree remove *)"
    "mcp__Git__git_add"
    "mcp__Git__git_branch"
    "mcp__Git__git_checkout"
    "mcp__Git__git_create_branch"
    "mcp__Git__git_diff"
    "mcp__Git__git_diff_staged"
    "mcp__Git__git_diff_unstaged"
    "mcp__Git__git_log"
    "mcp__Git__git_show"
    "mcp__Git__git_status"

    # --------------------------------------------------------------------------
    # GitHub / GitLab
    # --------------------------------------------------------------------------
    "mcp__GitHub"
    "mcp__GitLab"

    # --------------------------------------------------------------------------
    # Development
    # --------------------------------------------------------------------------
    "Bash(agent-browser *)"
    "Bash(cargo *)"
    "Bash(cmake *)"
    "Bash(fnm *)"
    "Bash(g++ *)"
    "Bash(gcc *)"
    "Bash(go *)"
    "Bash(make *)"
    "Bash(node *)"
    "Bash(npm *)"
    "Bash(npx *)"
    "Bash(pip *)"
    "Bash(pip3 *)"
    "Bash(pipx *)"
    "Bash(pnpm *)"
    "Bash(poetry *)"
    "Bash(pre-commit *)"
    "Bash(pytest *)"
    "Bash(python *)"
    "Bash(python3 *)"
    "Bash(ruff *)"
    "Bash(rustc *)"
    "Bash(rustup *)"
    "Bash(shellcheck *)"
    "Bash(uv *)"
    "Bash(uvx *)"
    "mcp__ide"

    # --------------------------------------------------------------------------
    # Nix
    # --------------------------------------------------------------------------
    "Bash(deadnix *)"
    "Bash(nix build *)"
    "Bash(nix derivation show *)"
    "Bash(nix develop *)"
    "Bash(nix eval *)"
    "Bash(nix flake archive *)"
    "Bash(nix flake check *)"
    "Bash(nix flake info *)"
    "Bash(nix flake metadata *)"
    "Bash(nix flake show *)"
    "Bash(nix fmt *)"
    "Bash(nix hash *)"
    "Bash(nix help *)"
    "Bash(nix log *)"
    "Bash(nix path-info *)"
    "Bash(nix print-dev-env *)"
    "Bash(nix repl *)"
    "Bash(nix search *)"
    "Bash(nix shell *)"
    "Bash(nix store ls *)"
    "Bash(nix store path-info *)"
    "Bash(nix why-depends *)"
    "Bash(nix-build *)"
    "Bash(nix-instantiate *)"
    "Bash(nix-prefetch-url *)"
    "Bash(nix-shell *)"
    "Bash(nix-tree *)"
    "Bash(nom *)"
    "Bash(nvd *)"
    "Bash(statix *)"

    # --------------------------------------------------------------------------
    # Containers
    # --------------------------------------------------------------------------
    "Bash(docker compose config *)"
    "Bash(docker compose logs *)"
    "Bash(docker compose ls *)"
    "Bash(docker compose ps *)"
    "Bash(docker images *)"
    "Bash(docker info *)"
    "Bash(docker inspect *)"
    "Bash(docker logs *)"
    "Bash(docker ps *)"
    "Bash(docker version *)"
    "Bash(helm dependency list *)"
    "Bash(helm env *)"
    "Bash(helm get *)"
    "Bash(helm history *)"
    "Bash(helm lint *)"
    "Bash(helm list *)"
    "Bash(helm plugin list *)"
    "Bash(helm repo list *)"
    "Bash(helm search *)"
    "Bash(helm show *)"
    "Bash(helm status *)"
    "Bash(helm template *)"
    "Bash(helm verify *)"
    "Bash(helm version *)"
    "Bash(kubectl api-resources *)"
    "Bash(kubectl config *)"
    "Bash(kubectl describe *)"
    "Bash(kubectl explain *)"
    "Bash(kubectl get *)"
    "Bash(kubectl logs *)"
    "Bash(kubectl version *)"
    "Bash(podman compose config *)"
    "Bash(podman compose logs *)"
    "Bash(podman compose ls *)"
    "Bash(podman compose ps *)"
    "Bash(podman images *)"
    "Bash(podman info *)"
    "Bash(podman inspect *)"
    "Bash(podman logs *)"
    "Bash(podman ps *)"
    "Bash(podman version *)"

    # --------------------------------------------------------------------------
    # Temporary Files
    # --------------------------------------------------------------------------
    "Read(//tmp/**)"
    "Write(//tmp/**)"
    "Edit(//tmp/**)"

    # --------------------------------------------------------------------------
    # Codex
    # --------------------------------------------------------------------------
    "mcp__Codex"
  ];

  # ============================================================================
  # Ask - Requires confirmation (write / destructive operations)
  # ============================================================================

  ask = [
    # --------------------------------------------------------------------------
    # Filesystem
    # --------------------------------------------------------------------------
    "Bash(rm *)"

    # --------------------------------------------------------------------------
    # System
    # --------------------------------------------------------------------------
    "Bash(kill *)"
    "Bash(killall *)"
    "Bash(pkill *)"
    "Bash(sudo *)"

    # --------------------------------------------------------------------------
    # Git
    # --------------------------------------------------------------------------
    "Bash(git branch -D *)"
    "Bash(git clean *)"
    "Bash(git push *)"
    "Bash(git reset *)"
    "Bash(git restore *)"
    "mcp__Git__git_reset"

    # --------------------------------------------------------------------------
    # GitHub / GitLab
    # --------------------------------------------------------------------------
    "mcp__GitHub__create_or_update_file"
    "mcp__GitHub__create_pull_request"
    "mcp__GitHub__create_repository"
    "mcp__GitHub__delete_file"
    "mcp__GitHub__fork_repository"
    "mcp__GitHub__issue_write"
    "mcp__GitHub__merge_pull_request"
    "mcp__GitHub__push_files"
    "mcp__GitHub__sub_issue_write"
    "mcp__GitHub__update_pull_request"
    "mcp__GitLab__approve_merge_request"
    "mcp__GitLab__create_branch"
    "mcp__GitLab__create_issue"
    "mcp__GitLab__create_issue_link"
    "mcp__GitLab__create_issue_note"
    "mcp__GitLab__create_label"
    "mcp__GitLab__create_merge_request"
    "mcp__GitLab__create_merge_request_discussion_note"
    "mcp__GitLab__create_merge_request_note"
    "mcp__GitLab__create_merge_request_thread"
    "mcp__GitLab__create_note"
    "mcp__GitLab__create_or_update_file"
    "mcp__GitLab__create_pipeline"
    "mcp__GitLab__create_repository"
    "mcp__GitLab__delete_issue"
    "mcp__GitLab__delete_issue_link"
    "mcp__GitLab__delete_label"
    "mcp__GitLab__delete_merge_request_discussion_note"
    "mcp__GitLab__delete_merge_request_note"
    "mcp__GitLab__merge_merge_request"
    "mcp__GitLab__push_files"
    "mcp__GitLab__resolve_merge_request_thread"
    "mcp__GitLab__unapprove_merge_request"
    "mcp__GitLab__update_issue"
    "mcp__GitLab__update_issue_note"
    "mcp__GitLab__update_label"
    "mcp__GitLab__update_merge_request"
    "mcp__GitLab__update_merge_request_discussion_note"
    "mcp__GitLab__update_merge_request_note"

    # --------------------------------------------------------------------------
    # Nix
    # --------------------------------------------------------------------------
    "Bash(agenix *)"
    "Bash(darwin-rebuild *)"
    "Bash(nix store delete *)"
    "Bash(nix store gc *)"
    "Bash(nix upgrade-nix *)"
    "Bash(nix-collect-garbage *)"
    "Bash(nixos-rebuild *)"

    # --------------------------------------------------------------------------
    # Containers
    # --------------------------------------------------------------------------
    "Bash(docker push *)"
    "Bash(helm push *)"
    "Bash(podman push *)"
  ];

  # ============================================================================
  # Deny - Always blocked
  # ============================================================================

  deny = [
    # agenix -r silently empties all secrets when stdin is not a TTY
    "Bash(agenix -r *)"
    "Bash(agenix --rekey *)"
  ];
}
