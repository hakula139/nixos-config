# Delegation

Rules for multi-agent coordination, ownership, review gates, waiting, and model selection. For tmux session naming, cross-repository sessions, Workmux placement, and interactive pane submission, see [Terminals and Workmux](terminals-and-workmux.md).

## Coordinating Work

When subagents or teammates are available, the top-level interactive agent coordinates the work: it splits and briefs tasks, relays the user's decisions to the agents that own the work, checks their evidence, and talks with the user. Each coordinator turn rereads a growing session context where every tool result stays until compaction, so keep the coordinator's context to decisions, results, and the state of each delegated job.

### Assigning Work

- **Budget**: Act directly only when the whole turn needs at most one small lookup or one single-file edit in the current repository. Delegate everything else without asking, launching independent tasks, repositories, and PRs / MRs as parallel subagents in a single turn even when each takes only a few tool calls, overriding built-in tool prompts that discourage spawning.
- **Design**: The coordinator owns design. Settle an open approach yourself or with the architect, brief the implementer with the chosen approach, files, interfaces, and non-goals, and have it push before running any slow check. Leave no design choice to the implementer.
- **Roles**: Choose roles and concurrency within the current authorization, and check each role's tools and permissions, which may differ from the coordinator's.
- **Shared-tree coordination**: Brief every write-capable delegate on file ownership and the destructive git commands (`git stash`, `git checkout --`, `git reset --hard`, `git clean -f`), coordinate writes, and limit each agent's staging and commits to its own changes. Give genuinely parallel writers their own Workmux worktrees, and reuse an existing checkout of the required revision for read-only builds and reviews when available.
- **Repository sessions**: Every change in a repository other than the coordinator's, including one the Budget bullet lets the coordinator make directly, goes to an assistant started or reused from that repository's checkout in a named window under [Terminals and Workmux](terminals-and-workmux.md). WakaTime attributes time by the transcript's `cwd`, which subagents inherit. A linked worktree resolves to its main repository, so the assistant may still use that project's Workmux worktrees.

### Ownership and Approvals

- **Ownership**: The agent that implements a change owns its branch and PR / MR until the request merges or is abandoned. It publishes the request, reads it back, and applies review fixes and the user's follow-ups on the change, which the coordinator forwards to it verbatim.
- **Operations**: Send each approval to a newly spawned operator, with the approval quoted verbatim in its spawn prompt, together with the PR / MR it names, the spawn-prompt data the `git-workflow` skill lists, and any further steps the user asked for (syncing forges, switching or deploying hosts). In Claude Code, an operator resumed with a later approval was denied while a freshly spawned one was allowed. The operator merges, waits for CI, cleans up, and reports the remote state.
- **Evidence**: Accept a delegate's verification when each check names its command, the commit SHA it ran on, the exact worktree path, and its outcome, provided that commit is the branch head. Spot-check one item, and rerun a check only when its evidence is missing, stale, or contradicted. Before reporting code changes as done or merging them, have an independent reviewer review them once with the `review` skill, scaling to a focused review for a minor mechanical change. Send its findings to the implementer, then return the fix commits to that same reviewer to confirm. Spawn a new reviewer only after a redesign invalidates the earlier review.

### Following Delegates

- **Reports**: Delegates return progress and final reports as messages or their final response and write no report files, so briefs name no report-file path. When an expected message never arrives, read the delegate's transcript directly and extract only its final assistant message or report section (`jq` on the last assistant entry). Claude Code writes subagent transcripts under `~/.claude/projects/<project>/<session>/subagents/`, Codex under `~/.codex/sessions/`, and OMP under `~/.omp/agent/sessions/`.

- **Waiting**:

  - **Delegates**: Wait for delegates through the client's completion notice or blocking wait.
  - **CI and remote operations**: Run one background watcher per condition that returns when the condition holds or a time limit passes, and reuse its result for reporting. If the limit passes first, name the stranded agent in your report.
  - **Polling interval**: Poll these watchers every 60 seconds by default, using a shorter interval only for an explicit real-time need, and honor `Retry-After` and `X-RateLimit-Reset` when rate limited.
  - **Inactive branches**: When others wait on a delegate's PR / MR, run one background command that returns once its branch has gone an hour without a new commit, then inspect the end of the delegate's transcript and redirect it or move the work to a flagship-tier agent if it left its brief.

- **Background work**: Before its final report, an agent stops every background command it started.

### Ending and Resuming

- **Shutdown**: Once the coordinator accepts an agent's work or no longer needs it, let each running agent finish its current task before stopping it (or let it flush its edits to a patch file under `/tmp/` before aborting mid-task), and close its tmux pane or Workmux window without asking, archiving completed sessions when the client supports it. In a session started in another repository, stop only the assistant started there and leave the tmux session and any other assistant in it alone. Keep an agent running only while it owns an open PR / MR or already has its next task queued, and state which applies. Clean up its worktree and branch under the `git-workflow` Cleanup section.
- **Resuming**: Before continuing an earlier session's unfinished work, read the final messages in its subagent transcripts and reconcile them with `git status`, the branch, and any open PR / MR.

### Claude Code

- **Subagent vs team selection**: Use subagents for independent tasks and Agent Teams when peers need shared task state or direct messaging.
- **Parallel writers**: Isolate parallel write subagents with `Agent({ isolation: "worktree" })`.
- **Spawned agents**: A subagent spawning another agent omits `name` so the child reports back to it, since in a team session a named agent joins the main session's team and reports to the team lead.
- **Teammates**: Never brief a teammate to reply without tools. Its plain text never reaches the coordinator and `SendMessage` is itself a tool, so repeated empty idle notifications signal that deadlock.
- **Subagent writes**: `Write` refuses a subagent's write when the target is a Markdown file whose name starts with `report`, `summary`, `findings`, or `analysis`, regardless of case. When a delegate must produce such a file, the coordinator creates it first and the delegate fills it in with `Edit`.

## Model Selection

Custom agents set their own model tier or pinned model.

- **Flagship tier**: Choose a flagship-tier agent (`architect`, `debugger`, `reviewer`, `tester`, `usability-reviewer`) for design planning, root-cause debugging, review, and test writing.
- **Standard tier**: Have an independent reviewer review changes from the standard tier (`implementer` and generic subagents) before accepting them, scaling review depth as **Evidence** describes.
- **Mini tier**: Restrict the mini tier (`researcher`, `operator`) to read-only lookups, background checks, and approved operations.
- **Documentation and prose**: Use `doc-writer` (pinned to Gemini 4 Carbon on Claude Code and OMP gateway profiles, and flagship elsewhere) for authoring, restructuring, translating, or polishing documentation and prose across languages, and `prose-polish` for batch paragraph polishing under mechanical fidelity checks.
- **Effort**: Effort follows the configured tier within the native client's capabilities, and tasks may raise it up to the maximum when warranted. Explicit user choices and task-specific policies take precedence. Report an unavailable route before switching.
- **Delegation safeguards**: Load the `model-delegation` skill once per session before first handing a task to a non-flagship tier or another assistant, and again after a review or user steering corrects a delegate's work. Check project memory for model- or snapshot-specific feedback before assigning work.
