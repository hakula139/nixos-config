---
name: disk-cleanup
description: >-
  Audit disk usage and reclaim space on macOS and NixOS hosts without losing live or personal data.
  Use when a disk is full or nearly full, when asked to free space or find what is using it, or
  before removing build outputs, caches, scratch copies, or agent worktrees in bulk.
---

# Disk Cleanup

Measure and classify every large item. Remove only what is safe, then report the space freed using before-and-after numbers.

## Measure

Start by running `df -h` on the affected volumes. On macOS, `df` excludes purgeable space, and APFS local snapshots retain deleted files until they are thinned, so also run `tmutil listlocalsnapshots /`. Then use `du -sh` to size the usual heavy spots, staying on one filesystem with `-x` and sorting the output:

| Location                                                                                                          | How to size it                                                                                   |
| ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `/private/tmp` (macOS) or `/tmp`                                                                                  | `du -xsh /private/tmp/* \| sort -h`. Agents often leave Cargo target dirs and review copies here |
| Agent worktrees, such as `.claude/worktrees/*` in each repository                                                 | `du -sh` on each worktree and its `target/`, `node_modules/`, or `result*` outputs               |
| `~/.cache/uv`, `~/.npm`, `~/.cargo/registry`, and the directories that `pnpm store path` and `brew --cache` print | `du -sh` on each path                                                                            |
| Nix store                                                                                                         | `nix store gc --dry-run` lists what garbage collection would delete                              |
| Docker                                                                                                            | `docker system df`                                                                               |

macOS's `tmp_cleaner` removes `/tmp` files that have been idle for at least 4 days, so a recent pile-up there reflects active work. If the numbers don't add up, investigate further, starting with `du -xh -d 1 ~ | sort -h`.

## Classify

Before deleting anything, sort every large item into a group:

- **Safe:** Regenerable output that nothing is using, such as stale build targets, package-manager caches, unused Docker images, dead store paths, and `/tmp` entries from finished work.
- **Needs the user's decision:** Anything whose loss the user would notice or that requires privileges you don't have, including personal app data such as VMs, chat app media, and game libraries, APFS local snapshots, dirty or unmerged worktrees, and anything you can't attribute to a known tool.
- **Keep:** Anything modified recently, anything a live process holds open or uses as its working directory, sockets, and runtime dirs such as `tmux-*` and `claude-*`.

Check whether a candidate is in use before treating it as safe. `find <path> \( -mtime -1 -o -ctime -1 \) -print -quit` prints a path if anything inside changed within the past day, while `lsof +D <path>` lists processes holding files open or using a directory inside it. Another agent may be using a worktree or scratch copy, so leave the candidate alone if its owner is unclear.

## Clean

- **Build output:** Run `cargo clean` in the project or worktree that owns a `target/`. Remove a target dir outside any project, such as one in `/tmp`, directly.
- **Caches:** `uv cache clean`, `pnpm store prune`, `npm cache clean --force`, and `brew cleanup --prune=all`.
- **Docker:** `docker image prune -a -f` removes images that no container uses. Leave volumes to the user because they hold data.
- **Nix store:** `nixgc` collects old generations and their garbage. It requires sudo, so give the command to the user.
- **Local snapshots:** `tmutil deletelocalsnapshots <date>` frees space used by a snapshot. It requires the user's decision and sudo, so give them the command too.
- **Agent worktrees:** Preserve their content as the `git-workflow` skill's Cleanup section describes, then remove them through the `clean-gone` skill or `git worktree remove`, which keep branch bookkeeping consistent.

Show the user the sizes and exact commands for items in the "needs the user's decision" group, then wait for them to choose. Report the space freed using a fresh `df -h`, and note that a local snapshot may keep the space unavailable until thinned.
