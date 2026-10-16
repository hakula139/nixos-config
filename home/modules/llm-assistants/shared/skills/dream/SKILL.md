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

A dream is a reflective pass over one project's memory store. It folds what recent sessions learned into durable, well-organized memories so that future sessions can orient quickly. The pass edits the memory store directly. Rules that have proven durable move through a PR / MR into the instruction files that own them, so an instruction file changes only when the user merges that PR / MR, after which a later dream retires the promoted memory.

## Locate the store

The target is the Claude Code auto-memory directory for the current project, which holds one fact per Markdown file plus a `MEMORY.md` index. Resolve it in this order:

1. The memory directory named by the host's own memory instructions, when the host provides them.
2. `~/.claude/projects/<slug>/memory/`, where `<slug>` is the main worktree's absolute path with every non-alphanumeric character replaced by `-`. Take the main worktree from the first `worktree` line of `git worktree list --porcelain`, since all worktrees of a repository share one store.

If the directory does not exist, report that and stop. Before the first edit, copy the store to a new directory under `/tmp/` and report its path, because the store sits outside version control and a bad merge cannot otherwise be undone.

Leave natively managed stores untouched and read them only as signal. Codex regenerates `~/.codex/memories/` through its own consolidation pipeline, and OMP keeps memory in `~/.omp/agent/agent.db`, so manual edits there are overwritten or bypass the host's schema.

The host's memory instructions define the file format, the memory types, and what is worth saving. When the host provides none, match the frontmatter, body structure, and index line shape of the files already in the store.

## Phase 1: Orient

- List the store, read `MEMORY.md`, and skim the topic files so new signal extends the entries that already cover its topic.
- Note the global instructions and the repository's `AGENTS.md` that are already loaded. A memory that repeats one of them is a removal candidate.
- If `logs/` or `sessions/` subdirectories exist, review their recent entries.
- The modification time of `<store>/.consolidate-lock` marks the last consolidation. When the file is absent, treat every session as recent.
- Record which memories were last modified before that stamp. Consolidation edits update modification times, and Phase 5 needs these original ages.

## Phase 2: Gather recent signal

Look for new information worth persisting, in rough priority order:

1. Daily logs under `logs/YYYY/MM/YYYY-MM-DD.md`, when present, which are the append-only stream.
2. Memories that drifted. Check every file, flag, option, command, and path a memory names against the current repository, and treat a contradiction as a fix to make at the source.
3. Transcripts touched since the last consolidation, from every assistant that worked on this project or one of its worktrees. Match sessions by the working directories that `git worktree list --porcelain` reports, since some worktrees live outside the main checkout.

- **Claude Code**: `~/.claude/projects/<slug>*/*.jsonl`, with one directory per worktree path.
- **Codex**: `~/.codex/memories/rollout_summaries/*.md`, condensed summaries with a `cwd:` header line that identify their raw transcripts under `~/.codex/sessions/` in `rollout_path:`.
- **OMP**: `~/.omp/agent/sessions/*/*.jsonl`, where the `"type":"session"` line records `cwd`.

Skip OpenCode because it stores sessions in SQLite. Transcripts are large, so select files with `find <dir> -newer <store>/.consolidate-lock` and grep them for narrow terms:

```bash
grep -n '<narrow term>' <selected transcripts> | tail -50
```

Search only for things you already suspect matter, such as user corrections, approaches the user confirmed, and failures that recurred across sessions. Never read transcripts exhaustively.

## Phase 3: Consolidate

Decide for each candidate whether it adds a memory, updates one, deletes one, or changes nothing.

- Merge new signal into the existing file that covers the topic.
- Resolve relative dates such as "yesterday" or "next Thursday" against when the memory was written, taken from its text or else the file's modification time. Once that date has passed, check whether the expected event or work has happened, and delete the memory when it is done or no longer applies. Otherwise rewrite it with the absolute date.
- Delete or correct a memory that the current repository or a later session contradicts.
- Save only what the host's memory rules admit. Facts already recorded by instruction files, code, or git history stay out.
- When a merge or rename retires a memory name, update every `[[name]]` link that pointed at it.
- Re-read a file immediately before rewriting it, because concurrent sessions may also write to the store.

A durable rule that belongs in an instruction file stays a memory during this phase, leaving Phase 5 to decide whether it is ready to move.

## Phase 4: Prune and index

Keep `MEMORY.md` under 200 lines and about 25 KB. It is an index, so each entry is one line under about 150 characters in the store's existing shape, and memory content never goes into it.

- Remove pointers to memories that are stale, wrong, or superseded.
- Shorten any line over about 200 characters by moving its detail into the topic file.
- Add pointers to newly important memories.
- Check that every memory file has exactly one pointer and every pointer resolves to a file.

## Phase 5: Promote

Promotion moves a memory into long-term knowledge, the instruction file that owns its rule. Because every future session loads that rule, promote only what has proven itself.

### Track earlier proposals

When a memory's frontmatter metadata holds `promotion: <URL>`, it was already proposed. Check that request's state using the hosting service's CLI, such as `gh pr view <URL> --json state` or `glab mr view <URL>`:

- **Merged**: delete the memory and its index line, then remove or reword every `[[name]]` link that pointed at it.
- **Closed without merging**: keep the memory and its `promotion` URL, and never propose it again.
- **Open**: leave the memory alone.

### Select candidates

A memory is a candidate only when all of these hold:

- Its type is `feedback` or `user`, the types that state durable rules and preferences.
- It survived an earlier dream, as Phase 1 recorded by a modification time older than the previous `.consolidate-lock` stamp, or two or more sessions corroborated it.
- It carries no `promotion` URL.

### Choose the target

Choose the most specific file that owns the rule:

- **One repository**: that repository's convention doc for the affected area, or its `AGENTS.md` when no convention doc fits.
- **Every project**: the global instruction sources in the nixos-config checkout, located as the `environment-repair` skill describes. `home/modules/llm-assistants/instructions/shared.md` holds rules for every assistant, and adjacent assistant files such as `claude-code.md` hold additions for one assistant. Sections rendered from an `@name@` placeholder live in `home/modules/llm-assistants/shared/prompt-fragments/`. Never edit rendered files such as `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`, because they are generated.
- **One skill's procedure**: that skill's source `SKILL.md`, which for shared skills sits under `home/modules/llm-assistants/shared/skills/` in nixos-config. Skip any skill whose source you cannot trace to a repository.

Read the target file before promoting a candidate. If the target already states the rule, delete the memory and its index line because the instruction now carries it. If the target's own admission rules reject the rule, such as a repository that admits only constraints a reader cannot infer from its code, keep it as a memory.

### Integrate

Rewrite each rule into the target's existing structure to match its writing conventions and repository documentation rules, merging it with any neighbouring rule it refines or generalizes so the section reads as one coherent set. Never paste memory text verbatim, and omit the memory's **Why** and **How to apply** scaffolding, keeping only the reasoning a reader needs to apply the rule correctly.

### Publish

Because instruction files are versioned, the PR / MR serves as the approval gate. Work unattended following the `git-workflow` skill and the target repository's `AGENTS.md`:

- Each dream opens or updates at most one PR / MR per target repository, always from the branch `docs/promote-memories`. When that branch has an open request, add the new promotions to it.
- Work in an isolated worktree under the repository's usual worktree location, leaving the main checkout and any other agent's uncommitted work untouched. Check out the open request's branch, or else start the branch from the remote default branch. When a closed request left a stale branch of that name, overwrite it with `git push --force-with-lease`, which loses nothing because the closed request keeps its commits.
- Run the repository's verification and pre-commit hooks, and never bypass them.
- Never merge, as merging stays with the user.
- For a public repository, keep private material out of the diff, commits, and description, including internal hostnames, gateway names, local paths, and private repositories. A rule that cannot be stated without such material stays a memory.

After publishing, add `promotion: <URL>` beside the type in each proposed memory's frontmatter metadata.

## Finish

After the pass completes, stamp it with `: > <store>/.consolidate-lock`. Claude Code's native auto-dream reads the same file's modification time, so either mechanism counts from the latest pass. Skip the stamp when the pass stopped early.

Report the backup path and a brief summary of what you consolidated, updated, or pruned, followed by the URL of each opened or updated PR / MR along with the memories it promotes and any memories retired because their promotion merged or their target already covered them. If nothing changed because the memories are already tight, say so.
