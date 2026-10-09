---
name: dream
description: >-
  Consolidate a project's file-based agent memory from recent sessions of any assistant: merge
  duplicates, fix drifted or contradicted facts, convert relative dates, prune stale entries, and
  rebuild the MEMORY.md index. Use when asked to dream, consolidate, reorganize, or clean up
  memories, or when the memory index has grown long, stale, or contradictory.
---

# Dream

A dream is a reflective pass over one project's memory store. It folds what recent sessions learned into durable, well-organized memories so that future sessions can orient quickly. The pass edits only the memory store. Instruction files change only after the user approves a proposal from the report.

## Locate the store

The target is the Claude Code auto-memory directory for the current project, which holds one fact per Markdown file plus a `MEMORY.md` index. Resolve it in this order:

1. The memory directory named by the host's own memory instructions, when the host provides them.
2. `~/.claude/projects/<slug>/memory/`, where `<slug>` is the main worktree's absolute path with every non-alphanumeric character replaced by `-`. Take the main worktree from the first `worktree` line of `git worktree list --porcelain`, since all worktrees of a repository share one store.

If the directory does not exist, report that and stop. Before the first edit, copy the store to a new directory under `/tmp/` and report its path, because the store sits outside version control and a bad merge cannot otherwise be undone.

Leave natively managed stores untouched and read them only as signal. Codex regenerates `~/.codex/memories/` through its own consolidation pipeline, and OMP keeps memory in `~/.omp/agent/agent.db`, so manual edits there are overwritten or bypass the host's schema.

The host's memory instructions define the file format, the memory types, and what is worth saving. When the host provides none, match the frontmatter, body structure, and index line shape of the files already in the store.

## Phase 1: Orient

- List the store, read `MEMORY.md`, and skim the topic files so you improve existing entries instead of creating near-duplicates.
- Note the global instructions and the repository's `AGENTS.md` that are already loaded. A memory that repeats one of them is a removal candidate.
- If `logs/` or `sessions/` subdirectories exist, review their recent entries.
- The modification time of `<store>/.consolidate-lock` marks the last consolidation. When the file is absent, treat every session as recent.

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
- Convert relative dates such as "yesterday" or "last week" to absolute dates.
- Delete or correct a memory that the current repository or a later session contradicts.
- Save only what the host's memory rules admit. Facts already recorded by instruction files, code, or git history stay out.
- When a merge or rename retires a memory name, update every `[[name]]` link that pointed at it.
- Re-read a file immediately before rewriting it, because concurrent sessions may also write to the store.

A durable rule that belongs in an instruction file goes into the report as a promotion proposal naming the target file. The memory stays in place until the user approves the move.

## Phase 4: Prune and index

Keep `MEMORY.md` under 200 lines and about 25 KB. It is an index, so each entry is one line under about 150 characters in the store's existing shape, and memory content never goes into it.

- Remove pointers to memories that are stale, wrong, or superseded.
- Shorten any line over about 200 characters by moving its detail into the topic file.
- Add pointers to newly important memories.
- Check that every memory file has exactly one pointer and every pointer resolves to a file.

## Finish

After the pass completes, stamp it with `: > <store>/.consolidate-lock`. Claude Code's native auto-dream reads the same file's modification time, so either mechanism counts from the latest pass. Skip the stamp when the pass stopped early.

Report the backup path and a brief summary of what you consolidated, updated, or pruned, followed by any promotion proposals. If nothing changed because the memories are already tight, say so.
