# Chinese Prose Quality

Why this repository rewrites Chinese prose with a hook, and what the measurements were that decided it.

## Abstract

The assistant's default Chinese output was judged unusable by the repository owner, who is a native speaker and the sole consumer of that output. Six rounds of blind human review, covering 78 samples across twelve models and five context frames, were used to locate the cause and test candidate fixes.

Three findings drove the design. Model identity dominates: under an identical prompt and frame, the weakest model scored 3.70 out of 10 while six others clustered between 7.00 and 8.33, a gap of 3.3 to 4.6 points. Context isolation is real but secondary, worth 1.80 points. Every automated proxy for quality failed, including three LLM judges, which ranked samples in reverse.

The resulting mechanism performs no classification. It routes Chinese prose to a model selected on measured rewrite quality, triggered structurally so it cannot be skipped. A pre-existing detector was removed.

## 1. Problem

The assistant writes Chinese for documentation, commit bodies, and conversational replies. The owner's assessment was that its output is markedly worse than that of the previous model generation, and that reading it costs more than rewriting it.

Automated quality measurement was attempted first and is reported here as a negative result, because its failure is what forced the design. Throughout, the single ground truth is the owner's blind scores on a 0 to 10 scale, and every mechanical or model-based signal is validated against them.

## 2. Method

Samples were generated for a fixed set of Chinese writing tasks, shuffled, stripped of model attribution, and scored blind. Model names were held in a separate key file, so a sample's provenance could not bias its score.

Six review rounds were run. Round 1 established a candidate pool across twelve models. Round 2 tested two-stage rewriting. Round 3 crossed five context frames against two models. Round 4 crossed six models against three tasks. Round 5 repeat-sampled the two frames whose difference the design depended on, five draws per arm. Round 6 compared seven rewriters on one shared draft.

Two design choices are worth stating because they changed conclusions. Rounds 4 and 5 replicated or crossed their conditions, after round 3 showed that a single draw is unreliable: one condition re-sampled at 4.0 having scored 10.0 in round 1. Round 5 also carried a falsification threshold fixed in writing before the samples were read, so the result could not be rationalised after the fact.

Absolute scores are comparable across rounds. The owner confirmed that a uniformly low-scoring round reflects uniformly worse text, since the reading does not tighten between rounds, and that is what makes the cross-round comparison in section 3.3 admissible.

## 3. Results

### 3.1 Automated judges rank in reverse

Sample pairs differing by at least 1.5 human points were put to three models, each pair in both orders, counting only pairs where the verdict survived an order swap. Two opposite framings were used, asking which sample was better and which read as more machine-written, so that a simple polarity error would show up as a sign flip.

`Agrees` is measured against the human ranking under both framings. Under _which is better_ it means the judge picked the higher-scoring sample. Under _more machine_ it means the judge called the lower-scoring sample the more machine-written one.

| Framing         | Judge            | Agrees | Disagrees | Order-unstable |
| --------------- | ---------------- | ------ | --------- | -------------- |
| Which is better | Gemini 3.7 Flash | 15.0%  | 51.7%     | 33.3%          |
| Which is better | Opus 4.7         | 18.3%  | 66.7%     | 15.0%          |
| Which is better | Opus 5           | 21.7%  | 75.0%     | 3.3%           |
| More machine    | Gemini 3.7 Flash | 21.7%  | 66.7%     | 11.6%          |
| More machine    | Opus 4.7         | 15.0%  | 70.0%     | 15.0%          |
| More machine    | Opus 5           | 10.0%  | 73.3%     | 16.7%          |

Agreement of 10% to 22% is far below the 50% a coin would give, and the sign did not flip when the question was inverted. Read through the definition above, the two framings say the same thing about the same samples. Low agreement on the first means the judges picked the owner's low-scoring samples as the better written ones. Low agreement on the second means they called the high-scoring samples the more machine-written ones, which leaves the low-scoring samples on the human side. A prompt that made one judge answer backwards cannot explain this, since that would have raised agreement under the opposite framing.

One mechanism explains both halves. The judges reward dense metaphor and ornamented diction, which is exactly what the owner's annotations deduct for. Best-of-N against any of these judges would select reliably worse output, so that route is closed.

### 3.2 Mechanical signals do not generalise

A seven-feature composite correlated at $\rho = -0.459$ with human scores in round 1, and $\rho = -0.450$ after controlling for length. Only one feature, particle density, carried the composite, while two others pointed the wrong way.

Adding quotation-mark density lifted the in-sample correlation to -0.633, and this was withdrawn after out-of-sample testing:

| Signal          | Round 1 ($n = 26$) | Round 3 ($n = 10$, held out) |
| --------------- | ------------------ | ---------------------------- |
| Composite score | -0.459             | -0.263                       |
| Quotation marks | -0.442             | **-0.013**                   |
| Combined        | -0.633             | **-0.201**                   |

The quotation signal vanished entirely. The cause was a single sample that imitated the owner's own writing, a register that uses corner brackets heavily: it had the highest quote count in the round and the second-highest score. The signal was tracking register.

Paragraph length, function-word density, adverb density, and information-item count all failed on held-out data as well. The strongest was paragraph length at $\rho = +0.100$, which is to say nothing.

### 3.3 Model identity dominates

Six models were crossed with three tasks under one frame. Within that set, no pair separated: the model effect was $F(5,10) = 1.19$, $p = 0.378$, against a task effect of $F(2,10) = 5.00$, $p = 0.031$. The largest observed pairwise gap, 1.33 points, sat just inside the 1.36-point half-width of its own confidence interval, and per-task rankings contradicted each other, with two of three inter-task rank correlations negative.

This nearly produced the wrong conclusion. The six models were all already good, so the design had measured spread within a restricted range and found none. Placing the weakest model on the same scale showed what the restriction had hidden:

| Condition                                | Score        |
| ---------------------------------------- | ------------ |
| Opus 5, with coding conversation history | 1.90         |
| Opus 5, clean context                    | 3.70         |
| The other six models, clean context      | 7.00 to 8.33 |

The gap between the weakest model and the weakest of the others is 3.30 points, and 4.63 to the best. Model choice is the largest single lever measured, roughly twice the next one.

### 3.4 English style rules help, and the coding context around them hurts

Five context frames were tested on two models. The project had assumed that the English phrasing doctrine in the assistant's instructions was suppressing Chinese, since it measurably shortens paragraphs and thins the function-word layer. The blind read reversed that.

| Frame                                     | Opus 5  | Opus 4.7 |
| ----------------------------------------- | ------- | -------- |
| Bare call, no style context               | 3.5     | 4.0      |
| **English doctrine alone**                | **6.0** | **7.0**  |
| English doctrine plus coding conversation | 4.0     | 4.0      |
| Chinese style rules as a checklist        | 3.0     | 4.0      |
| Two human sample paragraphs, no rules     | 5.0     | 6.0      |

The doctrine alone scored highest on both models. The harmful ingredient is the English coding conversation: adding three such turns cost 2 to 3 points on both models, while a bare call with no style context at all was near the bottom.

A Chinese rule checklist was worst, and human sample paragraphs came second with a side effect the owner named directly: "It imitates my own style a little too closely."

Repeat-sampling confirmed the frame effect at five draws per arm. The doctrine-only arm averaged 3.70 against 1.90 with coding history, a gap of 1.80 points ($t(8) = 2.76$, $p = 0.049$, AUC of 0.90), clearing the 1.0-point threshold fixed before reading. Mechanical measurement confirmed the manipulation landed: function-word density, paragraph length, and total length all moved with effect sizes of 0.70 to 1.50. Those metrics fail as quality predictors, but they are valid as a manipulation check, which is a different claim.

### 3.5 Rewriting is weaker than generating, and the best rewriter is not the best generator

Seven models rewrote one shared draft, itself real output scored 3.5 with the note "Punctuation is wrong, and sentences are still being clipped short."

| Rewriter                       | Score   |
| ------------------------------ | ------- |
| **Gemini 3.7 Flash**           | **9.0** |
| Qwen 3.6                       | 6.0     |
| Opus 4.6                       | 4.5     |
| Opus 4.7                       | 4.5     |
| GLM-5                          | 4.0     |
| Opus 5, rewriting its own text | 4.0     |
| DeepSeek V3.2                  | 3.5     |

Rewrite skill is close to unrelated to generation skill: across the earlier round the correlation between the two was $\rho = -0.103$. Two models that generate at 7.33 and 7.00 rewrite at 4.5, barely above the 4.0 a model scores rewriting its own output. The owner's summary of the low scorers: "A problem common to all of these is that they do not dare revise boldly, when the original phrasing is itself poor."

Two prompt defects were identified and removed before this round, which is why its numbers supersede the earlier rewrite round. Instructing the rewriter to preserve every information item is counterproductive, since the three most obedient models scored lowest. Supplying human sample paragraphs causes persona grafting, which cost five samples points.

One model was disqualified on a defect no score captures: DeepSeek V3.2 emitted Traditional Chinese, drawing "Why has this turned into Traditional Chinese? It is also too formal."

## 4. Mechanism

Section 3.1 and 3.2 rule out detection: no available signal separates good Chinese from bad at usable precision. Section 3.3 makes detection unnecessary anyway, because the variable that predicts quality is which model wrote the text, and that is known at generation time. A classifier for a variable you already control has nothing to contribute.

The implementation is a rewriter. `home/modules/llm-assistants/shared/hooks/pre-tool-use/zh-polish/` runs before any tool that carries prose out of the session, which means a file write, an interactive question, and the MCP calls that publish a page, a comment, or a commit body. It:

1. Takes only the span the tool call introduced, so prose already in a file is never rewritten, and for a file write takes only `.md`, since rewriting a source file to polish one Chinese comment would put the code around it at risk.
2. Requires 120 CJK characters outside fenced code for a whole-file write, and 8 for an edited span, a question, or an MCP field. A model usually rewrites one sentence at a time, so an edit is worth a call at a length a whole file would not be.
3. Sends the span to the model from section 3.5, under the doctrine from section 3.4 as a system prompt.
4. Rejects the result unless it is non-empty, within 0.55 to 1.6 times the original CJK length, and structurally identical in fenced blocks, inline code, headings, and link targets.
5. Returns the rewrite through `updatedInput` on success, and fails open on every error.

Two properties hold structurally. The rewrite is not routed through the generating model, so it cannot be quietly re-degraded in transit. And the hook fires on the tool call, so the generating model cannot skip it by forgetting to ask.

The doctrine is sliced out of the assistant's own instruction file at build time, so the two cannot drift apart.

Measured end to end on a sample the owner had scored low, the hook completed in 12 seconds and removed the half-width punctuation the owner had flagged. It also rejoined clipped sentences, which is the fault the doctrine targets: the sentence count fell while the mean sentence grew.

|                                              | Before | After |
| -------------------------------------------- | ------ | ----- |
| Half-width punctuation after a Han character | 2      | 0     |
| Sentences                                    | 13     | 10    |
| Mean sentence length, CJK characters         | 36.2   | 38.0  |
| CJK characters                               | 470    | 380   |

That first paragraph went in as:

> 禁令只能描述表层形式，无法触及产生这种形式的动机。模型接到「不许用破折号」之后，要表达的那个停顿、补充、转折依然存在，于是它换成冒号、括号、逗号加连接词，甚至干脆切成两个短句。原来那个句式是某种思维习惯留下的痕迹，痕迹被擦掉了，习惯还在，只好用更别扭的容器把同样的内容装出来。禁止「不是 A 而是 B」的结果，常常是「A 是错的。B 才对」——对照关系一点没少，还多了一股生硬的断裂感。

and came back as:

> 禁令只能限制表层的形式，管不住背后的表达动机。当模型被禁止使用某种标点或句式时，原本需要停顿、补充或转折的语意依然存在，它往往就会改用冒号、括号，甚至切成零碎的短句来替代。形式虽然被抹去了，底层的表达习惯还在，结果只能套进更别扭的结构里，反而平添一股生硬的断裂感。

The largest measured gain is the shared draft from section 3.5, which the owner scored 3.5, noting "Punctuation is wrong, and sentences are still being clipped short". The selected rewriter scored 9.0 on it. Both faults sit in the draft's third paragraph, which carries ten half-width commas and a shortest sentence of 12 characters:

> 还有一层是规则的表述方式。否定式的指令只画出边界,不给出落点,模型得自己猜什么算合格,猜的过程会占用它本该花在内容上的注意力,写出来的东西因此变得谨慎、拘谨、缺少推进感。更根本的是,那些让人不适的句式大多只是症状,底下的病因是一种把话说得像有力量的冲动——用形式上的对称、节奏上的顿挫来填补论证的空缺。症状被封住,冲动还在,它会找到新的出口。真正有用的约束通常是描述目标效果、给出正面样例、限定某类结构的出现上限,把判断权留在写作过程里面,而不是在外面砌一道墙。

and after, with no half-width mark and a shortest sentence of 36:

> 单纯的否定指令只划定了边界，模型在揣摩合格标准的过程中容易变得畏手畏脚，导致行文滞涩。那些招致反感的句式，根源通常在于试图用形式上的对仗和顿挫去掩盖论证本身的单薄。如果不解决立论的问题，单靠堵截表层的句式，表达冲动就会流向其他机械的形式。比较有效的做法是提供具体的正面样例，或者限定特定结构的出现频率，引导模型在写作过程中自主平衡。

The draft's opening paragraph shows neither fault, so a rewrite of it would demonstrate nothing. At 3.5 the draft also sits mid-scale, and the arm carrying coding history in section 3.4 averaged 1.90.

## 5. Coverage and limits

The mechanism covers text the assistant sends out through a tool, substituting its rewrite into the tool input at `PreToolUse` so the polished version is what lands. That reaches file writes, the MCP surfaces that publish prose (Confluence pages and comments, commit bodies, issue and merge-request text), and the prose of an interactive question. It does not cover conversational replies, and cannot: at the `Stop` event the response text is read-only, so a hook may block or inject context but not substitute the text a user sees.

The rewrite applies only where the host implements `updatedInput`, which the second assistant does not, so its edits go unpolished.

The transport constrains the model choice. The assistant CLI routes only one vendor's models, and every model from that vendor scored 4.0 to 4.5 as a rewriter, against 9.0 for the one selected. The hook calls the configured endpoint directly, reading its credentials and certificate path from the environment the assistant already runs in.

Statistical limits worth keeping in view. There is one reviewer, so nothing here separates their preferences from Chinese prose quality in general, and that distinction does not matter for the purpose but would matter for any wider claim. The frame effect rests on five draws per arm at $p = 0.049$. The rewriter ranking rests on one draw per model on one draft, so the ordering below the top score is not resolved, and a 9.0 from a single draw should be expected to regress. Sample counts per condition are between 1 and 5 throughout.

## 6. Ruled out

- **LLM judges as a reward or reranking signal.** Section 3.1, all six cells inverted.
- **Detecting bad Chinese from surface statistics.** Section 3.2, no signal survived held-out testing.
- **Selecting a model on Chinese quality among already-good models.** Section 3.3, six models across four vendors were statistically indistinguishable.
- **Chinese style rules written as a checklist.** Section 3.4, worst of five frames on both models.
- **Human sample paragraphs as a style anchor.** Section 3.4, effective but grafts the author's persona.
- **Two-stage drafting, where one model drafts and another rewrites.** Section 3.5, rewriting tops out below direct generation, so delegate the generation where the mechanism allows it.
- **Injecting an n-gram style prior at the logit layer.** Published negative result: too small has no effect, too large degrades into repetition loops.

## 7. What is checkable

The scores throughout are the owner's own blind reads, and the raw annotations and per-round analysis are not published, so the rankings here have to be taken on trust. What the repository does carry is the hook itself: its rules are sliced from the instruction file at build time, and its behaviour on a given payload can be reproduced by running it.
