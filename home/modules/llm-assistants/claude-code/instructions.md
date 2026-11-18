## Claude Code

- **Edit and Write**: Formatter and comment-gate hooks run only on `Edit` and `Write`, so use them for repository edits even when auto mode suggests `sed` or a heredoc.
- **Web search**: Native `WebSearch` requires an enabled profile, while `WebFetch` is always available.
- **Bash**: Pass literal paths to `rm` so Claude Code's safety check can resolve targets without prompting, and never start `command` with `#` (which breaks permission pattern matching, so put context in `description`).
- **Waiting**: End the turn when nothing else is pending so Claude Code resumes on background subagent completion or `run_in_background` Bash exit. Use one `run_in_background` command per wait, reserving `Monitor` for streams whose individual lines matter.
- **Compaction**: Preserve current task state, modified files, architecture decisions, code style requirements, and unresolved issues during compaction, and reread the project's `AGENTS.md` afterwards.
