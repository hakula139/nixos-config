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

- The model ID with its snapshot, such as `local_v2/DeepSeek-V4.1-Flash-1017`, since a new snapshot can alter the record.
- The task type and what required fixing or steering.
- Whether the brief left the gap, as gaps in the brief say nothing about the model.

One clear failure of the model's ability is enough to stop giving it that kind of task until its snapshot changes. The `dream` skill promotes these observations into the track record.

## Track record

- **Codex (GPT)**: assign only fully specified tasks with mechanically checkable results, such as an exact edit list, because it does not reliably infer conventions or make design decisions. Keep design decisions, convention judgments, and test writing with Claude.
- **DeepSeek V4.1 Flash (`local_v2/DeepSeek-V4.1-Flash-1017`)**: hand it implementation only with a detailed design from a flagship-tier agent that names the files, approach, edge cases, and checks, because it does not reliably design on its own. It takes no image input, so route tasks that read screenshots or images to an image-capable model.
