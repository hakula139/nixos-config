---
name: environment-repair
description: Delegate a local nixos-config repair when an assistant encounters a concrete tool or environment malfunction, while its main task continues.
---

# Environment Repair

A tool startup failure, broken managed setting, or reproducible environment regression can justify a background repair. Capture the failing command or operation and its relevant error, without exposing credentials. The worker must determine whether nixos-config owns the cause before editing. A remote outage, unavailable account permission, or ordinary project defect does not by itself justify changing host configuration.

## Locate the checkout

Read `${XDG_CONFIG_HOME:-$HOME/.config}/nixos-config/repository`. If that managed file is absent, use `NIXOS_CONFIG_DIR` when set. Both are generated from `hakula.nix.configPath`. The file takes precedence because an existing shell may retain an older environment value after activation.

Verify that the resolved directory is a Git checkout containing this repository's `flake.nix` and `AGENTS.md`. Resolve its main worktree with `git worktree list --porcelain` and inspect status before creating a branch. Do not infer a checkout from the Nix registry's immutable store snapshot or search arbitrary home directories. If the configured checkout is missing, report that blocker and continue the main task.

## Dispatch a repair

This policy authorizes creating a local repair branch and isolated worktree, making a scoped fix, running relevant checks, and committing that fix locally. Load `git-workflow` for those operations. Preserve the current checkout and any other agents' work. Use a unique `fix/` branch based on the configured checkout's current committed state, and record that base commit in the handoff. Do not move uncommitted changes into the repair worktree.

Use the current assistant's asynchronous subagent facility when it can run a bounded task in the specified repair worktree. Give it the full worktree path and require all edits and Git operations to use that directory. Native subagents may inherit the caller's working directory, so verify the worker's checkout before its first edit.

When native delegation cannot provide background execution, use Workmux from the configured repository with an explicit base, `--background`, a prompt file, and `--agent` matching the caller (`codex`, `claude`, `omp`, or `opencode`). Pass `--parent-session` for the target repository when launching across projects. Inspect `workmux add --help` for the installed version and verify the returned handle with its status commands. Workmux creates the isolated worktree itself. If neither route is available, report the limitation and continue the main task without claiming a worker was started.

The worker prompt must include:

- The failure evidence, affected tool, relevant task context, configured checkout, and repair worktree or Workmux ownership.
- A bounded diagnosis and fix for the cause owned by nixos-config, following its `AGENTS.md` and affected conventions.
- The shared-tree warning: other agents are working, so preserve their changes and edit only the assigned worktree and scope.
- No push, PR / MR creation, merge, or activation. Do not call `nixsw`, restart services, or change deployed configuration under this repair policy.
- Secret handling: never print or persist decrypted values. Preserve the main checkout's local `data/corp-domain.nix`. Inspect build requirements before copying that file into an isolated worktree, and never stage its real value.
- Required evidence: reproduce the problem where safe, verify the fix with an appropriate command, inspect the final diff, and report the branch, worktree, commit, checks, and remaining blockers.

Continue the original task while the worker runs, using a safe available workaround when appropriate. Check the worker through the delegation facility's real status and result mechanisms. Do not dispatch duplicate workers for the same failure or have a repair worker recursively launch another environment repair.

## Report the result

Inspect the returned diff and verification evidence before presenting the repair as complete. Keep the branch and worktree available for review. Include a short final status identifying the local repair, branch or commit, checks, and anything unfinished. If the worker is still running, say so with its actual handle and worktree. Do not promise a later notification unless the active delegation mechanism provides one.

Publishing or applying a repair requires a separate user instruction. This restriction applies to incidental background repairs, so it does not revoke publication or deployment already explicitly requested for the user's main task.
