---
name: model-delegation
description: >-
  Match delegated work to models by their track record, and record what reviews and user steering
  reveal about a delegate. Use once per session before the first handoff to a non-flagship tier or
  another assistant such as Codex, and again after a review or the user corrects a delegate's work.
---

# Model Delegation

Delegate according to configured tiers, using the track record below to narrow model assignments. A model lacking a record for a given task type receives work like any other delegate, with the standard review workflow judging the result.

## Recording

When a review or user steering corrects a delegate's work, save a `feedback` memory recording:

- The model ID with its snapshot, such as `local_v2/DeepSeek-V4.1-Flash-1017`, read from the delegate's transcript, since a profile can route a role to another model and a new snapshot can alter the record.
- The task type and what required fixing or steering.
- Whether the brief left the gap, as gaps in the brief say nothing about the model.

One clear failure of the model's ability is enough to stop giving it that kind of task until its snapshot changes. The `dream` skill promotes these observations into the track record.

## Track record

- **Codex (GPT)**: Assign only fully specified tasks with mechanically checkable results, such as an exact edit list, because it does not reliably infer conventions or make design decisions. Keep design decisions, convention judgments, and test writing with Claude.

- **DeepSeek V4.1 Flash (`local_v2/DeepSeek-V4.1-Flash-1017`)**: Hand it implementation only with a detailed design from a flagship-tier agent that names the files, approach, edge cases, and checks, because it does not reliably design on its own.

  - **Judgment**: Keep goal-based convention sweeps and fix rounds that need judgment with a flagship-tier agent, because it applied a layout goal unevenly across sibling files, applied a reviewer's mistaken suggestion literally, and deleted accepted rationale comments while moving code.
  - **Edge cases**: It follows exact edit lists and detailed review findings well, but it has mishandled edge cases even when the brief named them.
  - **Tests**: Keep test writing with Claude, because its tests have let plausible bugs survive at full line coverage, as a reviewer's mutation testing showed.
  - **UI work**: Hand it a measuring script and have a Claude reviewer check the result in a browser, because it has claimed a visual fix that a browser check showed had failed.
  - **Disagreement**: Require it to report disagreement with the brief, because it has overridden an explicit instruction over a concern that was already moot.
  - **Scope**: Give it an explicit stopping point, because it has spent hours on probes its brief did not ask for while a request others waited on stayed unpublished.
  - **Images**: Keep image-reading work off its gateway route, which rejects screenshots returned inside tool results with HTTP 400 and ends the agent mid-task.
