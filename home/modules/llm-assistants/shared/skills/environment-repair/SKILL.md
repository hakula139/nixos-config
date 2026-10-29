---
name: environment-repair
description: >-
  Delegate a nixos-config repair when an assistant encounters a concrete tool or environment
  malfunction, then publish the verified fix through a PR / MR while the main task continues.
---

# Environment Repair

Use this for a tool startup failure, a broken managed setting, or a reproducible environment regression that nixos-config may own. Remote outages, missing account permissions, and ordinary project defects do not qualify.

## Dispatch

1. Read the checkout path from `${XDG_CONFIG_HOME:-$HOME/.config}/nixos-config/repository`. If the file is missing or the path is not a nixos-config checkout, report the blocker and continue the main task.

2. Start one background worker on a unique `fix/` branch based on the checkout's current commit, recording that commit and leaving the checkout's uncommitted changes in place. Verify the worker's checkout before its first edit.

   - Prefer the assistant's native background subagents, in a worktree you create.
   - Otherwise, run `workmux add --background --base <commit> -P <prompt-file> <branch>` from the checkout, plus `--parent-session` across projects. Workmux creates the worktree itself.
   - If neither route exists, say so and continue.

3. Brief it with the failing command and redacted error, the full path of the worktree it owns, and its scope: determine whether nixos-config owns the cause, reproduce it where safe, fix it under the repository's `AGENTS.md`, verify the fix, and publish a PR / MR through `git-workflow` within any publication limit the task sets. It must not merge, activate (`nixsw`, service restarts), or start another repair.

Continue the main task meanwhile, and never dispatch a second worker for the same failure.

## Report

Inspect the diff, checks, and PR / MR before calling the repair done. Report the branch, commit, PR / MR URL or publication limit, checks, and anything unfinished, or the worker's handle and worktree while it runs. Promise a later notification only if the delegation mechanism supports one. Merging or activating the repair needs separate approval.
