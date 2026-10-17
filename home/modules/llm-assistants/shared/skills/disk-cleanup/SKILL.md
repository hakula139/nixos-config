---
name: disk-cleanup
description: >-
  Audit disk usage and reclaim space on macOS and NixOS hosts without losing live or personal data.
  Use when a disk is full or nearly full, when asked to free space or find what is using it, or
  before removing build outputs, caches, scratch copies, or agent worktrees in bulk.
---

# Disk Cleanup

Measure first, classify each large item, then remove only what is safe to remove. Report what you freed with numbers from before and after.

## Measure

Start with `df -h` for the affected volumes. On macOS, `df` excludes purgeable space, and APFS local snapshots keep deleted files on disk until the snapshots are thinned, so also run `tmutil listlocalsnapshots /`. Then size the usual heavy spots with `du -sh`, keeping to one filesystem with `-x` and sorting the output to find the largest entries:

| Location                                                                        | How to size it                                                                                   |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `/private/tmp` (macOS) or `/tmp`                                                | `du -xsh /private/tmp/* \| sort -h`. Agents often leave Cargo target dirs and review copies here |
| Agent worktrees, such as `.claude/worktrees/*` in each repository               | `du -sh` on each worktree and its `target/`, `node_modules/`, or `result*` outputs               |
| `~/.cache/uv`, `~/.npm`, `pnpm store path`, `brew --cache`, `~/.cargo/registry` | `du -sh` on each path                                                                            |
| Nix store                                                                       | `nix store gc --dry-run` lists what garbage collection would delete                              |
| Docker                                                                          | `docker system df`                                                                               |

Look beyond the table when the numbers don't add up, starting with `du -xh -d 1 ~ | sort -h`.

## Classify

Sort every large item into one of three groups before deleting anything:

- **Safe:** regenerable output that nothing is using, such as stale build targets, package-manager caches, unused Docker images, dead store paths, and `/tmp` entries from finished work.
- **Needs the user's decision:** anything whose loss the user would notice or that needs privileges you lack. This group includes personal app data such as VMs, chat app media, and game libraries, APFS local snapshots, dirty or unmerged worktrees, and anything you cannot attribute to a known tool.
- **Keep:** anything modified recently, anything a live process holds open or uses as its working directory, sockets, and runtime dirs such as `tmux-*` and `claude-*`.

Check liveness for each candidate before treating it as safe. `find <path> \( -mtime -1 -o -ctime -1 \) -print -quit` prints a path if anything inside changed within a day. `lsof +D <path>` lists processes that hold files open or use a directory inside it. Another agent may be using a worktree or scratch copy, so leave a candidate alone when its owner is unclear.

## Clean

- **Build output:** run `cargo clean` in the project or worktree that owns a `target/`. For a target dir outside any project, as in `/tmp`, remove the directory.
- **Caches:** `uv cache clean`, `pnpm store prune`, `npm cache clean --force`, and `brew cleanup --prune=all`.
- **Docker:** `docker image prune -a -f` removes images that no container uses. Leave volumes to the user, since they hold data.
- **Nix store:** `nixgc` collects old generations and the garbage they leave. It needs sudo, so hand the command to the user to run.
- **Agent worktrees:** before removing one, copy out unique gitignored content, such as agent memory directories, local settings, and notes. `git -C <worktree> status --short --ignored` lists the gitignored files. Diff each against its counterpart in the main checkout and merge what is missing there. Then remove the worktree through the `clean-gone` skill or `git worktree remove`, which keep the branch bookkeeping consistent.

Present the "needs the user's decision" group with sizes and the exact commands, and wait for the user to choose. Report the freed space, measured with `df -h` again, and remember that a local snapshot can keep it unavailable until it is thinned.
