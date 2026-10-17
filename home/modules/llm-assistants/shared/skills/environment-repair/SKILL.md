---
name: environment-repair
description: >-
  Delegate a nixos-config repair when an assistant encounters a concrete tool or environment
  malfunction, then publish the verified fix through a PR / MR while the main task continues.
---

# Environment Repair

A tool startup failure, a broken managed setting, or a reproducible environment regression can justify a background repair. A remote outage, missing account permission, or ordinary project defect alone does not. Capture the failing command and relevant error without exposing credentials, and require the worker to determine whether nixos-config owns the cause before editing.

## Locate the checkout

Read `${XDG_CONFIG_HOME:-$HOME/.config}/nixos-config/repository`, falling back to `NIXOS_CONFIG_DIR` only if that file is absent. Both paths come from `hakula.nix.configPath`. The file takes precedence because a shell that was already running may retain a stale environment value after activation.

Verify that the directory is a Git checkout containing this repository's `flake.nix` and `AGENTS.md`, resolve its main worktree with `git worktree list --porcelain`, and inspect its status before branching. Never infer a checkout from the Nix registry's store snapshot or by searching home directories. If the configured checkout is missing, report the blocker and continue the main task.

## Dispatch a repair

This policy authorizes a repair branch, an isolated worktree, and a scoped fix. After checks pass, commit, push, and create or update a dedicated PR / MR through `git-workflow`, unless the task explicitly limits publication. Base a unique `fix/` branch on the checkout's current committed state, record the base commit in the handoff, and never move uncommitted changes into the repair worktree.

Prefer the current assistant's asynchronous subagent facility when it can run a bounded task in the repair worktree. Give it the full worktree path and require it to use that path for every edit and Git operation. Native subagents may inherit the caller's working directory, so verify the worker's checkout before its first edit.

If native background execution is unavailable, launch Workmux from the configured repository with an explicit base, `--background`, a prompt file, and `--agent` for the selected assistant. When launching across projects, also add `--parent-session` for the target repository. Check `workmux add --help` for the installed version and verify the returned handle with its status commands. Workmux creates the isolated worktree itself. If neither route is available, report the limitation and continue the main task without claiming a worker started.

The worker prompt must include:

- The failure evidence, affected tool, relevant task context, configured checkout, and repair worktree or Workmux ownership.
- A bounded diagnosis and fix for the cause owned by nixos-config, following its `AGENTS.md` and relevant conventions.
- A warning that other agents are working in the shared tree, requiring the worker to preserve their changes and edit only its assigned worktree and scope.
- The publication scope: after verification, commit, push, and create or update the PR / MR, subject to any explicit per-task publication limits.
- Separate approval for merging or activation, including `nixsw`, service restarts, and deployed configuration changes.
- A requirement never to print or persist decrypted secret values.
- The required evidence: reproduce the problem where safe, verify the fix with an appropriate command, inspect the final diff, and report the branch, worktree, commit, checks, PR / MR URL or publication restriction, and remaining blockers.

Continue the original task meanwhile, using a safe workaround when available, and check the worker through the delegation facility's actual status and result mechanisms. Never dispatch duplicate workers for the same failure, and require repair workers never to launch another environment repair.

## Report the result

Inspect the returned diff, verification evidence, and any PR / MR metadata before presenting the repair as complete, and keep the branch and worktree available for review. The final status must name the repair, branch or commit, PR / MR URL or publication restriction, checks, and anything unfinished. If a worker is still running, provide its actual handle and worktree, and promise a later notification only if the delegation mechanism supports one.

Merging or activating a repair requires separate user approval. Explicit publication or deployment instructions for the main task retain their own scope.
