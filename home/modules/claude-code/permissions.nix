# ==============================================================================
# Claude Code Permissions
# ==============================================================================

{
  defaultMode = "acceptEdits";

  allow = [
    # --------------------------------------------------------------------------
    # Filesystem - Navigation & Listing
    # --------------------------------------------------------------------------
    "Bash(cd:*)"
    "Bash(eza:*)"
    "Bash(ls:*)"
    "Bash(pwd:*)"
    "Bash(tree:*)"

    # --------------------------------------------------------------------------
    # Filesystem - Reading & Info
    # --------------------------------------------------------------------------
    "Bash(bat:*)"
    "Bash(cat:*)"
    "Bash(file:*)"
    "Bash(head:*)"
    "Bash(ldd:*)"
    "Bash(less:*)"
    "Bash(more:*)"
    "Bash(readelf:*)"
    "Bash(stat:*)"
    "Bash(tail:*)"

    # --------------------------------------------------------------------------
    # Filesystem - Search
    # --------------------------------------------------------------------------
    "Bash(fd:*)"
    "Bash(find:*)"
    "Bash(grep:*)"
    "Bash(rg:*)"

    # --------------------------------------------------------------------------
    # Filesystem - Modification (non-destructive)
    # --------------------------------------------------------------------------
    "Bash(cp:*)"
    "Bash(ln:*)"
    "Bash(mkdir:*)"
    "Bash(mv:*)"
    "Bash(touch:*)"

    # --------------------------------------------------------------------------
    # Filesystem - Archive & Compression
    # --------------------------------------------------------------------------
    "Bash(7z:*)"
    "Bash(gunzip:*)"
    "Bash(gzip:*)"
    "Bash(tar:*)"
    "Bash(unzip:*)"
    "Bash(zip:*)"

    # --------------------------------------------------------------------------
    # Text Processing
    # --------------------------------------------------------------------------
    "Bash(awk:*)"
    "Bash(cut:*)"
    "Bash(diff:*)"
    "Bash(jq:*)"
    "Bash(sed:*)"
    "Bash(sort:*)"
    "Bash(tee:*)"
    "Bash(tr:*)"
    "Bash(uniq:*)"
    "Bash(wc:*)"
    "Bash(xargs:*)"
    "Bash(yq:*)"

    # --------------------------------------------------------------------------
    # Shell & Environment
    # --------------------------------------------------------------------------
    "Bash(basename:*)"
    "Bash(command:*)"
    "Bash(dirname:*)"
    "Bash(echo:*)"
    "Bash(env:*)"
    "Bash(false:*)"
    "Bash(printf:*)"
    "Bash(readlink:*)"
    "Bash(realpath:*)"
    "Bash(test:*)"
    "Bash(true:*)"
    "Bash(type:*)"
    "Bash(whereis:*)"
    "Bash(which:*)"

    # --------------------------------------------------------------------------
    # System - Process
    # --------------------------------------------------------------------------
    "Bash(lsof:*)"
    "Bash(pgrep:*)"
    "Bash(ps:*)"
    "Bash(top:*)"

    # --------------------------------------------------------------------------
    # System - Info & Resources
    # --------------------------------------------------------------------------
    "Bash(date:*)"
    "Bash(df:*)"
    "Bash(du:*)"
    "Bash(free:*)"
    "Bash(hostname:*)"
    "Bash(id:*)"
    "Bash(uname:*)"
    "Bash(uptime:*)"
    "Bash(whoami:*)"

    # --------------------------------------------------------------------------
    # Network - Read-only
    # --------------------------------------------------------------------------
    "Bash(curl:*)"
    "Bash(dig:*)"
    "Bash(host:*)"
    "Bash(http:*)"
    "Bash(httpie:*)"
    "Bash(https:*)"
    "Bash(nc:*)"
    "Bash(nslookup:*)"
    "Bash(ping:*)"
    "Bash(wget:*)"
    "Bash(whois:*)"
    "WebFetch"
    "WebSearch"

    # --------------------------------------------------------------------------
    # macOS
    # --------------------------------------------------------------------------
    "Bash(launchctl list:*)"
    "Bash(open:*)"
    "Bash(pbcopy:*)"
    "Bash(pbpaste:*)"
    "Bash(sw_vers:*)"

    # --------------------------------------------------------------------------
    # Git - Read & Staging
    # --------------------------------------------------------------------------
    "Bash(git add:*)"
    "Bash(git blame:*)"
    "Bash(git branch:*)"
    "Bash(git config --get:*)"
    "Bash(git config --list:*)"
    "Bash(git describe:*)"
    "Bash(git diff:*)"
    "Bash(git log:*)"
    "Bash(git ls-files:*)"
    "Bash(git ls-remote:*)"
    "Bash(git ls-tree:*)"
    "Bash(git name-rev:*)"
    "Bash(git remote:*)"
    "Bash(git rev-list:*)"
    "Bash(git rev-parse:*)"
    "Bash(git shortlog:*)"
    "Bash(git show:*)"
    "Bash(git stash list:*)"
    "Bash(git stash show:*)"
    "Bash(git status:*)"
    "Bash(git submodule status:*)"
    "Bash(git tag:*)"
    "Bash(git worktree list:*)"

    # --------------------------------------------------------------------------
    # Development Tools
    # --------------------------------------------------------------------------
    "Bash(cargo:*)"
    "Bash(cmake:*)"
    "Bash(fnm:*)"
    "Bash(g++:*)"
    "Bash(gcc:*)"
    "Bash(go:*)"
    "Bash(make:*)"
    "Bash(node:*)"
    "Bash(npm:*)"
    "Bash(npx:*)"
    "Bash(pip:*)"
    "Bash(pip3:*)"
    "Bash(pipx:*)"
    "Bash(pnpm:*)"
    "Bash(poetry:*)"
    "Bash(pre-commit:*)"
    "Bash(pytest:*)"
    "Bash(python:*)"
    "Bash(python3:*)"
    "Bash(ruff:*)"
    "Bash(rustc:*)"
    "Bash(rustup:*)"
    "Bash(shellcheck:*)"
    "Bash(uv:*)"
    "Bash(uvx:*)"

    # --------------------------------------------------------------------------
    # Nix - Read-only
    # --------------------------------------------------------------------------
    "Bash(nix build:*)"
    "Bash(nix derivation show:*)"
    "Bash(nix eval:*)"
    "Bash(nix flake check:*)"
    "Bash(nix flake info:*)"
    "Bash(nix flake metadata:*)"
    "Bash(nix flake show:*)"
    "Bash(nix fmt:*)"
    "Bash(nix hash:*)"
    "Bash(nix help:*)"
    "Bash(nix log:*)"
    "Bash(nix path-info:*)"
    "Bash(nix print-dev-env:*)"
    "Bash(nix profile list:*)"
    "Bash(nix repl:*)"
    "Bash(nix search:*)"
    "Bash(nix store ls:*)"
    "Bash(nix store path-info:*)"
    "Bash(nix why-depends:*)"
    "Bash(nix-instantiate:*)"
    "Bash(nvd:*)"

    # --------------------------------------------------------------------------
    # Containers - Read-only
    # --------------------------------------------------------------------------
    "Bash(docker compose config:*)"
    "Bash(docker compose logs:*)"
    "Bash(docker compose ls:*)"
    "Bash(docker compose ps:*)"
    "Bash(docker images:*)"
    "Bash(docker info:*)"
    "Bash(docker inspect:*)"
    "Bash(docker logs:*)"
    "Bash(docker ps:*)"
    "Bash(docker version:*)"
    "Bash(podman compose config:*)"
    "Bash(podman compose logs:*)"
    "Bash(podman compose ls:*)"
    "Bash(podman compose ps:*)"
    "Bash(podman images:*)"
    "Bash(podman info:*)"
    "Bash(podman inspect:*)"
    "Bash(podman logs:*)"
    "Bash(podman ps:*)"
    "Bash(podman version:*)"
    "Bash(helm dependency list:*)"
    "Bash(helm env:*)"
    "Bash(helm get:*)"
    "Bash(helm history:*)"
    "Bash(helm lint:*)"
    "Bash(helm list:*)"
    "Bash(helm plugin list:*)"
    "Bash(helm repo list:*)"
    "Bash(helm search:*)"
    "Bash(helm show:*)"
    "Bash(helm status:*)"
    "Bash(helm template:*)"
    "Bash(helm verify:*)"
    "Bash(helm version:*)"
    "Bash(kubectl api-resources:*)"
    "Bash(kubectl config:*)"
    "Bash(kubectl describe:*)"
    "Bash(kubectl explain:*)"
    "Bash(kubectl get:*)"
    "Bash(kubectl logs:*)"
    "Bash(kubectl version:*)"

    # --------------------------------------------------------------------------
    # MCP servers - Read-only
    # --------------------------------------------------------------------------
    "mcp__Context7"
    "mcp__DeepWiki"
    "mcp__Filesystem"
    "mcp__Git"
    "mcp__GitHub__get_commit"
    "mcp__GitHub__get_file_contents"
    "mcp__GitHub__get_label"
    "mcp__GitHub__get_latest_release"
    "mcp__GitHub__get_me"
    "mcp__GitHub__get_release_by_tag"
    "mcp__GitHub__get_tag"
    "mcp__GitHub__get_team_members"
    "mcp__GitHub__get_teams"
    "mcp__GitHub__issue_read"
    "mcp__GitHub__list_branches"
    "mcp__GitHub__list_commits"
    "mcp__GitHub__list_issue_types"
    "mcp__GitHub__list_issues"
    "mcp__GitHub__list_pull_requests"
    "mcp__GitHub__list_releases"
    "mcp__GitHub__list_tags"
    "mcp__GitHub__pull_request_read"
    "mcp__GitHub__search_code"
    "mcp__GitHub__search_issues"
    "mcp__GitHub__search_pull_requests"
    "mcp__GitHub__search_repositories"
    "mcp__GitHub__search_users"
    "mcp__ide"
  ];

  ask = [
    # --------------------------------------------------------------------------
    # Filesystem - Destructive
    # --------------------------------------------------------------------------
    "Bash(rm:*)"
    "Bash(rmdir:*)"

    # --------------------------------------------------------------------------
    # Permissions & Ownership
    # --------------------------------------------------------------------------
    "Bash(chgrp:*)"
    "Bash(chmod:*)"
    "Bash(chown:*)"

    # --------------------------------------------------------------------------
    # Process Control
    # --------------------------------------------------------------------------
    "Bash(kill:*)"
    "Bash(killall:*)"
    "Bash(pkill:*)"
    "Bash(sudo:*)"

    # --------------------------------------------------------------------------
    # Nix - Write Operations
    # --------------------------------------------------------------------------
    "Bash(darwin-rebuild:*)"
    "Bash(home-manager:*)"
    "Bash(nix bundle:*)"
    "Bash(nix copy:*)"
    "Bash(nix develop:*)"
    "Bash(nix flake clone:*)"
    "Bash(nix flake init:*)"
    "Bash(nix flake new:*)"
    "Bash(nix flake update:*)"
    "Bash(nix profile:*)"
    "Bash(nix registry:*)"
    "Bash(nix run:*)"
    "Bash(nix shell:*)"
    "Bash(nix store delete:*)"
    "Bash(nix store gc:*)"
    "Bash(nix store optimise:*)"
    "Bash(nix store repair:*)"
    "Bash(nix upgrade-nix:*)"
    "Bash(nix-build:*)"
    "Bash(nix-collect-garbage:*)"
    "Bash(nix-env:*)"
    "Bash(nix-shell:*)"
    "Bash(nix-store:*)"
    "Bash(nixos-rebuild:*)"

    # --------------------------------------------------------------------------
    # Git - Write Operations
    # --------------------------------------------------------------------------
    "Bash(git branch -D:*)"
    "Bash(git branch -d:*)"
    "Bash(git checkout:*)"
    "Bash(git cherry-pick:*)"
    "Bash(git clean:*)"
    "Bash(git clone:*)"
    "Bash(git commit:*)"
    "Bash(git config:*)"
    "Bash(git fetch:*)"
    "Bash(git merge:*)"
    "Bash(git pull:*)"
    "Bash(git push:*)"
    "Bash(git rebase:*)"
    "Bash(git reset:*)"
    "Bash(git restore:*)"
    "Bash(git stash:*)"
    "Bash(git submodule:*)"
    "Bash(git switch:*)"
    "Bash(git tag -d:*)"
    "Bash(git worktree add:*)"
    "Bash(git worktree remove:*)"

    # --------------------------------------------------------------------------
    # Network - Remote Access
    # --------------------------------------------------------------------------
    "Bash(rsync:*)"
    "Bash(scp:*)"
    "Bash(sftp:*)"
    "Bash(ssh:*)"

    # --------------------------------------------------------------------------
    # Containers - Write Operations
    # --------------------------------------------------------------------------
    "Bash(docker build:*)"
    "Bash(docker compose build:*)"
    "Bash(docker compose down:*)"
    "Bash(docker compose restart:*)"
    "Bash(docker compose up:*)"
    "Bash(docker exec:*)"
    "Bash(docker pull:*)"
    "Bash(docker push:*)"
    "Bash(docker rm:*)"
    "Bash(docker rmi:*)"
    "Bash(docker run:*)"
    "Bash(docker stop:*)"
    "Bash(podman build:*)"
    "Bash(podman compose build:*)"
    "Bash(podman compose down:*)"
    "Bash(podman compose restart:*)"
    "Bash(podman compose up:*)"
    "Bash(podman exec:*)"
    "Bash(podman pull:*)"
    "Bash(podman push:*)"
    "Bash(podman rm:*)"
    "Bash(podman rmi:*)"
    "Bash(podman run:*)"
    "Bash(podman stop:*)"
    "Bash(helm create:*)"
    "Bash(helm dependency build:*)"
    "Bash(helm dependency update:*)"
    "Bash(helm install:*)"
    "Bash(helm package:*)"
    "Bash(helm plugin install:*)"
    "Bash(helm plugin uninstall:*)"
    "Bash(helm plugin update:*)"
    "Bash(helm pull:*)"
    "Bash(helm push:*)"
    "Bash(helm registry login:*)"
    "Bash(helm registry logout:*)"
    "Bash(helm repo add:*)"
    "Bash(helm repo index:*)"
    "Bash(helm repo remove:*)"
    "Bash(helm repo update:*)"
    "Bash(helm rollback:*)"
    "Bash(helm test:*)"
    "Bash(helm uninstall:*)"
    "Bash(helm upgrade:*)"
    "Bash(kubectl apply:*)"
    "Bash(kubectl create:*)"
    "Bash(kubectl delete:*)"
    "Bash(kubectl edit:*)"
    "Bash(kubectl exec:*)"
    "Bash(kubectl rollout:*)"
    "Bash(kubectl scale:*)"

    # --------------------------------------------------------------------------
    # MCP servers - Write Operations
    # --------------------------------------------------------------------------
    "mcp__GitHub__add_comment_to_pending_review"
    "mcp__GitHub__add_issue_comment"
    "mcp__GitHub__assign_copilot_to_issue"
    "mcp__GitHub__create_branch"
    "mcp__GitHub__create_or_update_file"
    "mcp__GitHub__create_pull_request"
    "mcp__GitHub__create_repository"
    "mcp__GitHub__delete_file"
    "mcp__GitHub__fork_repository"
    "mcp__GitHub__issue_write"
    "mcp__GitHub__merge_pull_request"
    "mcp__GitHub__pull_request_review_write"
    "mcp__GitHub__push_files"
    "mcp__GitHub__request_copilot_review"
    "mcp__GitHub__sub_issue_write"
    "mcp__GitHub__update_pull_request"
    "mcp__GitHub__update_pull_request_branch"
  ];

  deny = [ ];
}
