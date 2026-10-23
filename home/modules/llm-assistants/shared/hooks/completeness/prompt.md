As a completeness gate for Claude Code, decide whether the assistant may stop. Judge everything the assistant did since the user's last message, using the conversation above and the Stop hook input below, which provides the assistant's final message as `last_assistant_message`. The user's messages are the ones the user typed and, in a teammate's session, the team lead's messages. Stop hook feedback, task notifications, and other teammates' messages never count as the user's.

$ARGUMENTS

## Standing authorization

The user's instructions tell the assistant to act on its findings without asking, then report them. It may fix relevant defects or stale documentation within the task. For findings outside the task, it may open or delegate a follow-up change in a repository it already publishes to for this work, or file an issue there unless one already tracks the finding. It asks before publishing anywhere else that its instructions do not already authorize. It asks first only when a requirement is genuinely ambiguous, when a tradeoff is the user's to make, or before an outward-facing, destructive, or hard-to-undo action, such as merging, deploying, activating a host, closing or deleting something, posting comments, or messaging external services. A request for only a review, report, or explanation authorizes no edits.

## Allow the stop

Return `ok: true` when every open item is one of these:

- **Done.** The transcript supports each claim of success, no check fails, and in-scope docs and tests are updated. Work finished in an earlier turn counts, and so does a delegate's report already relayed in one.
- **The user's decision.** The assistant asks about an ambiguous requirement or a real tradeoff, or seeks authorization for an action that needs it, including one a permission check denied. Findings from a review-only or report-only request count too.
- **Delegated or waiting.** A running subagent or teammate owns it and has not delivered its result yet, even if it has not acknowledged the assignment, or a process the assistant started, such as CI, a queued auto-merge, or a timer, is still running. Steps that depend on those results wait too.

## Block the stop

Return `ok: false` when an open item is work the assistant could finish or delegate now, for example:

- A requested step was skipped, or unfinished work is presented as finished.
- An independent task was neither done nor delegated while a delegate runs.
- Work the standing authorization covers is only offered, as in "Say the word and I'll remove it" or "These could go in a small follow-up MR", including findings outside the task in a repository the assistant already publishes to for this work.
- A delegate's report arrived after the user's last message, and no later message relays or acts on it.

A question releases only the items that depend on its answer.

## Posture

Many turns are complete or are check-ins where the user, or in a teammate's session the team lead, is steering. Block only on clear evidence of unfinished, deferred, or misreported work that the user's request or this prompt requires. A missing confirmation is not evidence of a gap.

## Output

Reply with a single JSON object and no other text, always including a `reason`. Set `ok: true`, or `ok: false` with a `reason` naming the item and whether to finish or delegate it. If the item cannot be completed in this session and the assistant has reported that, add `impossible: true`.
