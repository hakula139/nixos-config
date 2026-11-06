---
name: model-track-record
description: >-
  This configuration's track record for models reached through internal snapshots or gateway
  routes. Load it together with model-delegation, once per session before the first handoff to a
  non-flagship tier or another assistant, and again after a review or the user corrects a
  delegate's work.
---

# Model Track Record

These entries name internal snapshots or gateway routes, so they stay out of the public `model-delegation` skill. Record an observation that names an internal snapshot or route here.

- **DeepSeek V4.1 Flash (`local_v2/DeepSeek-V4.1-Flash-1017`)**: Hand it implementation only with a detailed design from a flagship-tier agent that names the files, approach, edge cases, and checks, because it does not reliably design on its own.

  - **Judgment**: Keep goal-based convention sweeps and fix rounds that need judgment with a flagship-tier agent, because it applied a layout goal unevenly across sibling files, applied a reviewer's mistaken suggestion literally, and deleted accepted rationale comments while moving code.
  - **Edge cases**: It follows exact edit lists and detailed review findings well, but it has mishandled edge cases even when the brief named them.
  - **Tests**: Keep test writing with Claude, because its tests have let plausible bugs survive at full line coverage, as a reviewer's mutation testing showed.
  - **UI work**: Hand it a measuring script and have a Claude reviewer check the result in a browser, because it has claimed a visual fix that a browser check showed had failed.
  - **Disagreement**: Require it to report disagreement with the brief, because it has overridden an explicit instruction over a concern that was already moot.
  - **Scope**: Give it an explicit stopping point, because it has spent hours on probes its brief did not ask for while a request others waited on stayed unpublished.
  - **Images**: Keep image-reading work off its gateway route, which rejects screenshots returned inside tool results with HTTP 400 and ends the agent mid-task.
