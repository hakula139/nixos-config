---
name: dream
description: >-
  Consolidate a project's file-based agent memory from recent sessions of any assistant: merge
  duplicates, fix drifted or contradicted facts, convert relative dates, prune stale entries, and
  rebuild the MEMORY.md index. Then promote mature rules into the instruction files that own them
  through PRs / MRs. Use when asked to dream, consolidate, reorganize, or clean up memories, or
  when the memory index has grown long, stale, or contradictory.
---

# Dream

A dream combines what recent sessions have learned into one project's memory store by editing it directly. Rules that prove durable move into the instruction files responsible for them through a PR / MR, which the user merges. A later dream then retires the promoted memory.

## Locate the store

The target is the current project's Claude Code auto-memory directory. It contains one fact per Markdown file and a `MEMORY.md` index. Resolve its location in this order:

1. The memory directory named in the host's memory instructions, if any.
2. `~/.claude/projects/<slug>/memory/`, where `<slug>` is the main worktree's absolute path with every non-alphanumeric character replaced by `-`. All worktrees share one store, so identify the main worktree from the first `worktree` line in `git worktree list --porcelain`.

If the directory does not exist, report that and stop. Before the first edit, copy the store to a new directory under `/tmp/` and report its path. The store is unversioned, so a bad merge cannot otherwise be undone.

Use natively managed stores only as a source of context, and never edit them. Codex regenerates `~/.codex/memories/` through its own pipeline, and OMP stores memory in `~/.omp/agent/agent.db`. Manual edits are either overwritten or bypass the host's schema.

The host's memory instructions define the file format, memory types, and what is worth saving. If there are no such instructions, follow the frontmatter, body structure, and index lines in the existing files.

## Phase 1: Orient

- List the store, read `MEMORY.md`, and skim the topic files so new signal builds on entries that already cover the same topic.
- Note the loaded global instructions and the repository's `AGENTS.md`. Memories that repeat those instructions are candidates for removal.
- Review recent entries in any `logs/` or `sessions/` subdirectories.
- The modification time of `<store>/.consolidate-lock` marks the last consolidation. If the file is absent, treat every session as recent.
- Record which memories were last modified before that timestamp. Consolidation edits reset modification times, and Phase 5 needs the original ages.

## Phase 2: Gather recent signal

Look for new information worth persisting, in rough priority order:

1. Daily logs under `logs/YYYY/MM/YYYY-MM-DD.md`, the append-only stream, if present.
2. Drifted memories. Check every file, flag, option, command, and path named in a memory against the current repository, and correct any contradiction at its source.
3. Transcripts touched since the last consolidation from every assistant that worked on this project or its worktrees. Match sessions using the working directories reported by `git worktree list --porcelain`, since some worktrees are outside the main checkout.

- **Claude Code**: `~/.claude/projects/<slug>*/*.jsonl`, with one directory per worktree path.
- **Codex**: `~/.codex/memories/rollout_summaries/*.md`, condensed summaries with a `cwd:` header line and a `rollout_path:` naming the raw transcript under `~/.codex/sessions/`.
- **OMP**: `~/.omp/agent/sessions/*/*.jsonl`, where the `"type":"session"` line records `cwd`.

Skip OpenCode, which stores sessions in SQLite. Transcripts are large, so use `find <dir> -newer <store>/.consolidate-lock` to select files, then grep them for narrow terms:

```bash
grep -n '<narrow term>' <selected transcripts> | tail -50
```

Search only for suspected signal, such as user corrections, approaches the user confirmed, and failures that recurred across sessions. Never read transcripts exhaustively.

## Phase 3: Consolidate

For each candidate, decide whether it adds, updates, or deletes a memory, or leaves the store unchanged.

- Merge new signal into the existing file for its topic.
- Resolve relative dates such as "yesterday" or "next Thursday" based on when the memory was written, using its text or, if that is unavailable, the file's modification time. Once the date has passed, check whether the expected event occurred. Delete the memory if it is done or no longer applies. Otherwise, rewrite it with the absolute date.
- Delete or correct memories contradicted by the current repository or a later session.
- Save only information allowed by the host's memory rules, omitting facts already recorded in instruction files, code, or git history.
- When a merge or rename retires a memory name, update every `[[name]]` link to it.
- Re-read each file immediately before rewriting it, since concurrent sessions may write to the store.

Keep durable rules that belong in an instruction file as memories during this phase. Phase 5 decides whether to move them.

## Phase 4: Prune and index

Keep `MEMORY.md` under 200 lines and about 25 KB. It is an index with one line per memory, each about 150 characters or fewer in the store's existing format. Never put memory content in the index.

- Remove pointers to stale, incorrect, or superseded memories.
- Move details from any line over about 200 characters into its topic file.
- Add pointers to newly important memories.
- Check that every memory file has exactly one pointer and that every pointer resolves to a file.

## Phase 5: Promote

Every future session loads an instruction file, so promote only memories that have proven durable.

### Track earlier proposals

A memory whose frontmatter includes `promotion: <URL>` has already been proposed. Check the request's state using the hosting service's CLI, such as `gh pr view <URL> --json state` or `glab mr view <URL>`:

- **Merged**: delete the memory and its index line, then remove or reword every `[[name]]` link to it.
- **Closed without merging**: keep the memory and its `promotion` URL. Never propose it again.
- **Open**: leave the memory unchanged.

### Select candidates

A memory is a candidate only when all of these hold:

- Its type is `feedback` or `user`, the types used for durable rules and preferences.
- It survived an earlier dream, as shown by a Phase 1 modification time older than the previous `.consolidate-lock` timestamp, or was corroborated by two or more sessions.
- It has no `promotion` URL.

### Choose the target

Choose the most specific file that owns the rule:

- **One repository**: the convention doc for the affected area, or `AGENTS.md` if no convention doc applies.
- **Every project**: the global instruction sources in the nixos-config checkout, located as described in the `environment-repair` skill. `home/modules/llm-assistants/instructions/shared.md` contains rules for every assistant, and adjacent files such as `claude-code.md` contain additions for a single assistant. Sections rendered from an `@name@` placeholder live in `home/modules/llm-assistants/shared/prompt-fragments/`. Never edit generated files such as `~/.claude/CLAUDE.md` or `~/.codex/AGENTS.md`.
- **One skill's procedure**: the skill's source `SKILL.md`. Shared skills live under `home/modules/llm-assistants/shared/skills/` in nixos-config. Skip any skill whose source cannot be traced to a repository.

Read the target before promoting a rule. If it already states the rule, delete the memory and its index line. If its admission rules reject the rule, such as when a repository admits only constraints a reader cannot infer from its code, keep the memory.

### Integrate

Rewrite each rule to fit the target's structure, writing conventions, and documentation rules. Merge it with any neighbouring rule it refines or generalizes so the section reads as a coherent set. Never paste memory text verbatim. Remove the **Why** and **How to apply** scaffolding, keeping only the reasoning readers need to apply the rule.

### Publish

The PR / MR is the approval gate. Work unattended under the `git-workflow` skill and the target repository's `AGENTS.md`:

- Open or update at most one PR / MR per target repository per dream, always from the `docs/promote-memories` branch. Add to its open request if one exists.
- Work in an isolated worktree in the repository's usual worktree location, leaving the main checkout and other agents' uncommitted work untouched. Check out the open request's branch, or branch from the remote default branch if there is no open request. If a closed request left a stale branch with that name, overwrite it with `git push --force-with-lease`. The closed request retains its commits, so nothing is lost.
- Run the repository's verification and pre-commit hooks. Never bypass them.
- Never merge. The user handles merging.
- In public repositories, keep private material out of the diff, commits, and description, including internal hostnames, gateway names, local paths, and private repositories. Keep a rule in memory if it cannot be stated without such material.

After publishing, add `promotion: <URL>` beside the type in each proposed memory's frontmatter metadata.

## Finish

Mark a completed pass with `: > <store>/.consolidate-lock`. Skip the stamp if the pass stops early. Claude Code's native auto-dream reads the same file's modification time, so both mechanisms count from the latest pass.

Report the backup path, briefly summarize what you consolidated, updated, or pruned, and give the URL of each opened or updated PR / MR along with the memories it promotes. Also report memories retired because their promotion merged or their target already covered them. If the memories were already concise and nothing changed, say so.
