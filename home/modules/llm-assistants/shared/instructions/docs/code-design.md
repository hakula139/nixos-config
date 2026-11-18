# Code Design

Rules for software design, planning, simplicity, and cleanup across repositories.

## Planning

- Before implementing a new subsystem, research the options, draft the design with its tradeoffs and open questions in a plan file under the gitignored `.agents/plans/`, and agree on it with the user. Small fixes and well-specified changes skip this step. When work starts in an area, check the plans for follow-ups deferred until that work, and resolve them in the same change or note why each stays deferred.
- Keep `.agents/plans/` for ongoing work. Delete a plan when its PR / MR merges or its decision is made, after moving durable facts to memory, documentation, an instruction file, or the PR / issue / commit body. Keep scratch scripts in `/tmp` or the worktree's build directory.
- If a requirement is hard to satisfy cleanly, weigh narrowing or revising it before adding complexity.
- Solve each problem at its cause with a clean design, and apply a temporary workaround only when the user explicitly asks for one.
- When a tool the user maintains lacks a capability the request needs, build it within the task, with the refactor, tests, and docs it takes, and brief delegates to carry the request through end to end. Ask first only when the build needs authorization you lack (spending money, publishing to an unauthorized external target).
- For findings outside the task, open or delegate a separate follow-up change in a repository you already publish to for this work, or file an issue there unless one already tracks the finding. Ask before publishing anywhere else that your instructions do not already authorize. Fix a finding about an unversioned local file in place or record it in memory, and file nothing about it.

## Simplicity

Aim for a simple, coherent design that meets current requirements without speculative features, configurability, or extension points. Simplicity means a clean, DRY structure, even when that takes more code than the shortest version.

- Refactor or extract when doing so clarifies responsibilities, simplifies control flow, or removes duplication, even if there is only one caller or the refactor spans many files.
- Avoid speculative defensive code. Trust established internal contracts, validate external inputs, and handle the failures required by the contract. Add guards, retries, or fallbacks only for concrete failure modes, and treat one added without that justification as a defect to remove. Let errors that expose broken assumptions surface.
- Use the framework's or library's own primitive before writing a helper that reproduces it. Before hand-writing substantial logic, look for a well-maintained library that provides it, and prefer dependencies already in the tree.
- Set tool policies in the tool's config file, and keep commands plain. Use environment variables only for settings without a config option, secrets, and per-environment values.

## Cleanup

- Remove stale or redundant material when asked. When cleaning up code, preserve required behavior while simplifying.
- During a requested cleanup, resolve routine ambiguities from the consumer's current behavior and report the decisions. Do not leave backup or "before" snapshots. Merge settings that still matter into the live file that consumes them, following its format and the Secret Handling rules in the global instructions.
