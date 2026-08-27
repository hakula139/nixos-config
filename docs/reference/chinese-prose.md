# Chinese Prose Quality

Why this repository generates Chinese prose through a rewrite hook instead of a detector, and what the measurements were that decided it.

## Abstract

The assistant's default Chinese output was judged unusable by the repository owner, who is a native speaker and the sole consumer of that output.
Six rounds of blind human review, covering 78 samples across twelve models and five context frames, were used to locate the cause and test candidate fixes.

Three findings drove the design.
Model identity dominates: under an identical prompt and frame, the weakest model scored 3.70 out of 10 while six others clustered between 7.00 and 8.33, a gap of 3.3 to 4.6 points.
Context isolation is real but secondary, worth 1.80 points.
Every automated proxy for quality failed, including three LLM judges, which ranked samples in reverse.

The resulting mechanism performs no classification.
It routes Chinese prose to a model selected on measured rewrite quality, triggered structurally so it cannot be skipped.
A pre-existing detector was removed.

## 1. Problem

The assistant writes Chinese for documentation, commit bodies, and conversational replies.
The owner's assessment was that its output is markedly worse than that of the previous model generation, and that reading it costs more than rewriting it.

Automated quality measurement was attempted first and is reported here as a negative result, because its failure is what forced the design.
Throughout, the single ground truth is the owner's blind scores on a 0 to 10 scale; every mechanical or model-based signal is validated against them.

## 2. Method

Samples were generated for a fixed set of Chinese writing tasks, shuffled, stripped of model attribution, and scored blind.
Model names were held in a separate key file, so a sample's provenance could not bias its score.

Six review rounds were run.
Round 1 established a candidate pool across twelve models.
Round 2 tested two-stage rewriting.
Round 3 crossed five context frames against two models.
Round 4 crossed six models against three tasks.
Round 5 repeat-sampled the two frames whose difference the design depended on, five draws per arm.
Round 6 compared seven rewriters on one shared draft.

Two design choices are worth stating because they changed conclusions.
Rounds 4 and 5 used crossed or replicated designs rather than one draw per condition, after round 3 showed that a single draw is unreliable: one condition re-sampled at 4.0 having scored 10.0 in round 1.
Round 5 also carried a falsification threshold fixed in writing before the samples were read, so the result could not be rationalised after the fact.

Absolute scores are comparable across rounds.
The owner confirmed that a uniformly low-scoring round reflects uniformly worse text rather than a stricter reading, which is what makes the cross-round comparison in section 3.3 admissible.

## 3. Results

### 3.1 Automated judges rank in reverse

Sample pairs differing by at least 1.5 human points were put to three models, each pair in both orders, counting only pairs where the verdict survived an order swap.
Two opposite framings were used, asking which sample was better and which read as more machine-written, so that a simple polarity error would show up as a sign flip.

| Framing         | Judge            | Agrees | Disagrees | Order-unstable |
| --------------- | ---------------- | ------ | --------- | -------------- |
| Which is better | Gemini 3.7 Flash | 15.0%  | 51.7%     | 33.3%          |
| Which is better | Opus 4.7         | 18.3%  | 66.7%     | 15.0%          |
| Which is better | Opus 5           | 21.7%  | 75.0%     | 3.3%           |
| More machine    | Gemini 3.7 Flash | 21.7%  | 66.7%     | 11.6%          |
| More machine    | Opus 4.7         | 15.0%  | 70.0%     | 15.0%          |
| More machine    | Opus 5           | 10.0%  | 73.3%     | 16.7%          |

Agreement of 10% to 22% is far below the 50% a coin would give, and the sign did not flip when the question was inverted.
Both framings therefore place the owner's low-scoring samples on the same side: the judges read them as both better written and more human.

One mechanism explains both halves.
The judges reward dense metaphor and ornamented diction, which is exactly what the owner's annotations deduct for.
Best-of-N against any of these judges would select reliably worse output, so that route is closed.

### 3.2 Mechanical signals do not generalise

A seven-feature composite correlated at rho = -0.459 with human scores in round 1, and -0.450 after controlling for length.
Only one feature, particle density, carried the composite; two others pointed the wrong way.

Adding quotation-mark density lifted the in-sample correlation to -0.633, and this was withdrawn after out-of-sample testing:

| Signal          | Round 1 (n=26) | Round 3 (n=10, held out) |
| --------------- | -------------- | ------------------------ |
| Composite score | -0.459         | -0.263                   |
| Quotation marks | -0.442         | **-0.013**               |
| Combined        | -0.633         | **-0.201**               |

The quotation signal vanished entirely.
The cause was a single sample that imitated the owner's own writing, a register that uses corner brackets heavily: it had the highest quote count in the round and the second-highest score.
The signal was tracking register, not quality.

Paragraph length, function-word density, adverb density, and information-item count all failed on held-out data as well.
The strongest was paragraph length at rho = +0.100, which is to say nothing.

### 3.3 Model identity dominates

Six models were crossed with three tasks under one frame.
Within that set, no pair separated: the model effect was F(5,10) = 1.19, p = 0.378, against a task effect of F(2,10) = 5.00, p = 0.031.
The largest observed pairwise gap, 1.33 points, sat just inside the 1.36-point half-width of its own confidence interval, and per-task rankings contradicted each other, with two of three inter-task rank correlations negative.

This nearly produced the wrong conclusion.
The six models were all already good, so the design had measured spread within a restricted range and found none.
Placing the weakest model on the same scale showed what the restriction had hidden:

| Condition                                | Score        |
| ---------------------------------------- | ------------ |
| Opus 5, with coding conversation history | 1.90         |
| Opus 5, clean context                    | 3.70         |
| The other six models, clean context      | 7.00 to 8.33 |

The gap between the weakest model and the weakest of the others is 3.30 points, and 4.63 to the best.
Model choice is the largest single lever measured, roughly twice the next one.

### 3.4 English coding context is what degrades Chinese, not English style rules

Five context frames were tested on two models.
The project had assumed that the English phrasing doctrine in the assistant's instructions was suppressing Chinese, since it measurably shortens paragraphs and thins the function-word layer.
The blind read reversed that.

| Frame                                     | Opus 5  | Opus 4.7 |
| ----------------------------------------- | ------- | -------- |
| Bare call, no style context               | 3.5     | 4.0      |
| **English doctrine alone**                | **6.0** | **7.0**  |
| English doctrine plus coding conversation | 4.0     | 4.0      |
| Chinese style rules as a checklist        | 3.0     | 4.0      |
| Two human sample paragraphs, no rules     | 5.0     | 6.0      |

The doctrine alone scored highest on both models.
The harmful ingredient is the English coding conversation: adding three such turns cost 2 to 3 points on both models, while a bare call with no style context at all was near the bottom.

A Chinese rule checklist was worst, and human sample paragraphs came second with a side effect the owner named directly: "It imitates my own style a little too closely."

Repeat-sampling confirmed the frame effect at five draws per arm.
The doctrine-only arm averaged 3.70 against 1.90 with coding history, a gap of 1.80 points (t(8) = 2.76, p = 0.049, AUC 0.90), clearing the 1.0-point threshold fixed before reading.
Mechanical measurement confirmed the manipulation landed: function-word density, paragraph length, and total length all moved with effect sizes of 0.70 to 1.50.
Those metrics fail as quality predictors, but they are valid as a manipulation check, which is a different claim.

### 3.5 Rewriting is weaker than generating, and the best rewriter is not the best generator

Seven models rewrote one shared draft, itself real output scored 3.5 with the note "Punctuation is wrong, and sentences are still being clipped short."

| Rewriter                       | Score   |
| ------------------------------ | ------- |
| **Gemini 3.7 Flash**           | **9.0** |
| Qwen3.6                        | 6.0     |
| Opus 4.6                       | 4.5     |
| Opus 4.7                       | 4.5     |
| GLM-5                          | 4.0     |
| Opus 5, rewriting its own text | 4.0     |
| DeepSeek V3.2                  | 3.5     |

Rewrite skill is close to unrelated to generation skill: across the earlier round the correlation between the two was rho = -0.103.
Two models that generate at 7.33 and 7.00 rewrite at 4.5, barely above the 4.0 a model scores rewriting its own output.
The owner's summary of the low scorers: "A problem common to all of these is that they do not dare revise boldly, when the original phrasing is itself poor."

Two prompt defects were identified and removed before this round, which is why its numbers supersede the earlier rewrite round.
Instructing the rewriter to preserve every information item is counterproductive, since the three most obedient models scored lowest.
Supplying human sample paragraphs causes persona grafting, which cost five samples points.

One model was disqualified on a defect no score captures: DeepSeek V3.2 emitted Traditional Chinese, drawing "Why has this turned into Traditional Chinese? It is also too formal."

## 4. Mechanism

Section 3.1 and 3.2 rule out detection: no available signal separates good Chinese from bad at usable precision.
Section 3.3 makes detection unnecessary anyway, because the variable that predicts quality is which model wrote the text, and that is known at generation time rather than inferred from it.
A classifier for a variable you already control has nothing to contribute.

The implementation is therefore a rewriter, not a gate.
`home/modules/llm-assistants/shared/hooks/post-tool-use/zh-polish/` runs after `Write` and `Edit`, and:

1. Acts only on `.md` files, and only on the span the tool call introduced, so prose already in the file is never rewritten.
2. Skips spans under 120 CJK characters outside fenced code, where a model call buys nothing.
3. Sends the span to the model from section 3.5, under the doctrine from section 3.4 as a system prompt.
4. Rejects the result unless it is non-empty, within 0.55 to 1.6 times the original CJK length, and structurally identical in fenced blocks, inline code, headings, and link targets.
5. Writes back only on success, and fails open on every error.

Two properties are structural rather than instructed.
The rewrite is not routed through the generating model, so it cannot be quietly re-degraded in transit.
And the hook fires on the tool call, so the generating model cannot skip it by forgetting to ask.

The doctrine is sliced out of the assistant's own instruction file at build time rather than copied, so the two cannot drift apart.

Measured end to end on the round 5 sample that scored 2.0, the hook completed in 15 seconds and eliminated the half-width punctuation the owner flagged in three separate annotations:

|                                                  | Before | After |
| ------------------------------------------------ | ------ | ----- |
| Half-width punctuation after a Chinese character | 2      | 0     |

The first paragraph, before:

> 禁令只能描述表层形式，无法触及产生这种形式的动机。模型接到「不许用破折号」之后，要表达的那个停顿、补充、转折依然存在，于是它换成冒号、括号、逗号加连接词，甚至干脆切成两个短句。

and after:

> 负面规则通常只能约束表层的字句形式，却管不住背后的表达动机。当模型被禁止使用破折号或某种特定句式时，原本想表达的停顿与转折依然存在，它往往就会换用括号、冒号或者生硬的短句来替代。

## 5. Coverage and limits

The mechanism covers text written to files.
It does not cover conversational replies, and cannot: at the `Stop` event the response text is read-only, so a hook may block or inject context but not substitute the text a user sees.

Tool inputs are coverable in principle through `PreToolUse` and its `updatedInput` field, which would bring interactive question text into scope.
That is not implemented.

The transport constrains the model choice.
The assistant CLI routes only one vendor's models, and every model from that vendor scored 4.0 to 4.5 as a rewriter, against 9.0 for the one selected.
The hook therefore calls the configured endpoint directly, reading its credentials and certificate path from the environment the assistant already runs in.

Statistical limits worth keeping in view.
There is one reviewer, so nothing here separates their preferences from Chinese prose quality in general, and that distinction does not matter for the purpose but would matter for any wider claim.
The frame effect rests on five draws per arm at p = 0.049.
The rewriter ranking rests on one draw per model on one draft, so the ordering below the top score is not resolved, and a 9.0 from a single draw should be expected to regress.
Sample counts per condition are between 1 and 5 throughout.

## 6. Ruled out

- **LLM judges as a reward or reranking signal.** Section 3.1, all six cells inverted.
- **Detecting bad Chinese from surface statistics.** Section 3.2, no signal survived held-out testing.
- **Selecting a model on Chinese quality among already-good models.** Section 3.3, six models across four vendors were statistically indistinguishable.
- **Chinese style rules written as a checklist.** Section 3.4, worst of five frames on both models.
- **Human sample paragraphs as a style anchor.** Section 3.4, effective but grafts the author's persona.
- **Two-stage drafting, where one model drafts and another rewrites.** Section 3.5, rewriting tops out below direct generation, so delegate the generation where the mechanism allows it.
- **Injecting an n-gram style prior at the logit layer.** Published negative result: too small has no effect, too large degrades into repetition loops.

## 7. Reproduction

The review bundles, per-round analysis scripts, and the owner's raw annotations are kept outside version control, under `zh-quality/` in the working tree.
The numbers in this document are recomputed by the `review*.py` scripts there.
