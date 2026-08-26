# Chinese prose gate

Read this before changing this gate, its judge prompt, or the classifier's fitted constants.

A `PostToolUse` hook that reads the Chinese the assistant just wrote and, when it reads as machine-generated, hands back a correction to apply in place. It emits `additionalContext` without halting and fails open, so a break costs a missed catch rather than a blocked edit. Its English sibling, `../../scripts/prose-gate.nu` with its prompt at `../../prompts/prose-tics.md`, is a rule list plus a judge and needs no more explanation than that prompt gives. This one puts a statistical classifier in front of the judge, because the tics it looks for are ratios rather than phrases, and because judging every edit would be too slow to leave enabled.

| File                | Role                                                                 |
| ------------------- | -------------------------------------------------------------------- |
| `zh-prose-gate.nu`  | The hook: classify first, judge only a flagged passage               |
| `zh-fingerprint.py` | The classifier: measures ratios and scores them against fitted means |
| `zh-prose-tics.md`  | The judge's system prompt                                            |

`zh-prose-gate.nu` is templated from `../../default.nix`, which substitutes store paths for the prompt, the classifier, and `timeout`. The judge's prompt stays in English apart from its specimens and its own `fix`, since an all-Chinese prompt doubles as the judge's model of normal Chinese and drags its prescriptions toward the register it should be flagging. Its own prescriptions scored 0.37 colons and semicolons per clause against 0.13 once the scaffolding moved to English.

## Why this gate needs a classifier

English AI tics are lexical, so a prompt can name them: `it's not X, it's Y`, a triad of parallel clauses, `In summary`. The Chinese equivalents live in proportions. Assistant Chinese keeps roughly the words a human would use while importing an English punctuation hierarchy, drops the adverbs and particles that pad ordinary Chinese, and repeats its own content words less. None of that shows up in a single phrase, which is why the gate measures it instead of matching on it.

The inventory that turned out **not** to separate is worth as much as the one that did. Clause length, burstiness, and most of the textbook 欧化 list are chance-level on this corpus. How much of the rest survives outside the corpus it was fitted on is the subject of [Measured rates](#measured-rates), and the answer there is discouraging enough to read first.

## What gets measured

`measure()` segments the passage with `jieba` and returns seven ratios. Each assistant column gives the side that assistant's fitted mean sits on relative to the human mean, with the class gap in pooled standard deviations at 85 characters, the corpus median.

| Feature | Definition                                        | `claude-code` | `codex`      |
| ------- | ------------------------------------------------- | ------------- | ------------ |
| `ttr`   | distinct words / words                            | higher, 0.67  | higher, 1.05 |
| `adv`   | adverb (`d`) share of POS tags                    | lower, 0.18   | level, 0.02  |
| `part`  | particle (`u`) share of POS tags                  | lower, 0.41   | lower, 0.96  |
| `noun`  | noun (`n`) share of POS tags                      | lower, 0.53   | higher, 0.07 |
| `link`  | colons and semicolons per clause                  | higher, 0.37  | higher, 0.70 |
| `reuse` | repeated word bigrams / bigrams                   | lower, 0.56   | lower, 0.65  |
| `pent`  | Shannon entropy over punctuation-mark frequencies | higher, 0.76  | higher, 0.34 |

The two columns disagree on `noun`, where both classes are flat in length and `codex` sits above the human mean at every length. Two `codex` cells carry no usable gap, `adv` at 0.02 sd and `noun` at 0.07 sd, so neither moves a `codex` score much either way. The gap moves with length wherever the fit has a slope: `claude-code` `pent` runs 0.34 at 45 characters and 2.03 at 584, and `codex` `ttr` shrinks from 1.13 to 0.82 across the same range. The report therefore ships both fitted means per ratio and the judge prompt reads each direction off them.

Three more ride along in the report for the judge to read and are never scored: hedge and attitude-adverb rates per 1000 characters with the matching words, plus a count of `不是……而是` antithesis constructions. They give the judge concrete vocabulary for its `fix`, and folding them into the score would double-count what `adv` already sees. Their own discrimination is weak, and it weakened further when the floor dropped to 45 characters, since a short paragraph has fewer chances to contain a hedge. An empty hedge-and-attitude pair covers three fifths of human paragraphs against four fifths of model ones, a likelihood ratio of 1.34. The judge prompt is calibrated to that, replacing the 3× it inherited from the old ≥60-character population.

## Length-conditional means

`ttr`, `reuse`, and `pent` all move with passage length, because a short paragraph has fewer chances to repeat itself. The previous version scored against one fixed centroid per class, fitted at the corpus median of about 85 characters, so it read a short human paragraph as assistant-flavored and a long assistant paragraph as human. That bias is what held its floor at 60 characters.

Each class mean is a function of length, and the score is the difference of squared standardized distances to the two means:

$$\mu_{c,k}(n) = a_{c,k} + b_{c,k} \ln n$$

$$\text{score} = \sum_k \frac{(x_k - \mu_{\text{human},k}(n))^2 - (x_k - \mu_{\text{assistant},k}(n))^2}{\text{sd}_k^2}$$

Positive means nearer this assistant's mean than a human's. Both $b$ terms are pinned to zero for the four features with no length trend, so no parameters go on fitting a flat line. Outside the fitted range the means become extrapolation, so `LN_CHARS_RANGE` clamps $\ln n$ to the interval the fit covers.

Expanding the square is what answers the weighting question directly:

$$(x - h)^2 - (x - a)^2 = (a - h)(2x - h - a)$$

Each feature's coefficient is proportional to the gap between its two class means at that length, divided by its pooled variance. A feature whose classes converge at 50 characters contributes almost nothing there and can dominate at 300, so the weights slide with $n$ without anyone choosing them. One pooled residual deviation per feature keeps this a diagonal LDA, since the corpus is far too small to fit a full quadratic discriminant.

## Paragraph scoring and the floor

A payload splits on blank lines and every admissible paragraph scores separately, because comparing a 3000-character diff against means fitted for 85 characters asks the wrong question. The highest-scoring paragraph carries the verdict, and only that paragraph reaches the judge. `strip_blocks` removes frontmatter, fences, `:::` containers and HTML comments from the whole payload first, since each of those can hold a blank line and would otherwise survive the split as prose: before that ordering was fixed, a fence containing two Chinese string literals was the winning passage on a payload whose only real prose was elsewhere.

The split needs a genuinely blank line, which the payloads this hook sees often do not carry. This repo soft-wraps Markdown one sentence per line, and on the `apply_patch` path the hook keeps the added lines only and joins them with single newlines, so the blank separators between paragraphs are context lines that never reach the classifier. A Chinese documentation edit therefore usually arrives as one chunk: $k$ stays 1, the worst-of-$k$ floor never grows past 3.04, and `body_chars` is the sum of those lines. On three paragraphs of 51, 47 and 45 characters, blank lines between them give $k = 3$ and a floor of 4.39, while single newlines give $k = 1$, a floor of 3.04, and one 143-character unit. The one-scored-unit-per-paragraph intent above does not hold for a soft-wrapped payload. Splitting on single newlines would push most units under the 45-character floor, so which unit is right here is unsettled.

The report the judge receives carries `means`, the two class means fitted at the scored paragraph's own length, one pair per ratio. An earlier version reported medians taken once at the corpus median length, which reintroduced for the judge exactly the length bias the score had been fixed to remove: at 45 characters the fitted human `ttr` mean is 0.851 against a reported median of 0.737, so most human paragraphs read as above it, and `pent` inverted outright.

Taking a maximum over $k$ paragraphs is a multiple comparison, so a longer payload draws more chances at the same threshold. The floor grows to pay for them, as `SCORE_FLOOR + FLOOR_PER_LOG_PARA * ln(k)`. `SCORE_FLOOR = 3.04` is the 80th percentile of scores over the typed-Chinese calibration set, so one typed paragraph trips it about one time in five, and `FLOOR_PER_LOG_PARA = 1.23` holds that rate roughly constant as $k$ grows.

Both were calibrated on typed Chinese. The same floor rejects 21.0% of typed paragraphs against 4.6% of essay paragraphs, a gap of 2.8 points of median score. The 20% an 80th percentile implies holds by construction on the calibration set it was taken over, while the 21.0% is a separate measurement over the 648 typed paragraphs that serve as negatives in [Clean held-out text](#clean-held-out-text). Nothing recorded here says those two populations are the same paragraphs, and one in five is the figure to carry for either. A hook payload is usually typed-register prose, so calibrating on essays would have set the floor far too low in practice.

`admissible()` also refuses anything under 45 characters, under 30% CJK density, or under 55% CJK among alphabetic characters. The density floor stops a table of digits with one Chinese character in it from reading as 100% Chinese.

## Corpus

Human prose comes from the author's own Chinese essays, split so that a reserve tier of documents is never used for fitting. Assistant prose comes from `~/.claude/projects` and `~/.codex` transcripts. Three filters apply: a date cut at 2026-08-12 to keep out text the current models were trained on, one paragraph cap per session so a single long conversation cannot dominate, and paragraph-level `strip_noise` first. The positive set held out for evaluation differs in kind on purpose: it is the added lines of one merge request in an unrelated repository, presentation notes Claude drafted in a spoken register, one short line per paragraph, which is the shape the gate misses.

| Class                       | Units ≥45c | Sources | Median chars |
| --------------------------- | ---------- | ------- | ------------ |
| human, reserve tier         | 676        | 56      | 85           |
| human, all essays           | 759        | 62      | 92           |
| `claude-code`               | 325        | 26      | 80           |
| of which the held-out notes | 99         | 1       | 82           |
| `codex`                     | 251        | 24      | 80           |

The 99 note units are counted inside the 325, so whether the fit excluded them is not recorded here, and the 0.548 clean-text AUC below reads as held out only if it did.

Cross-validation splits by source document and never by paragraph, since paragraphs from one file share topic and diction, so a random split would leak both. Re-derive the constants rather than editing them by hand: `ASSISTANTS` is a fit, and nudging one row breaks the pooled variance the rest of that row depends on.

One contamination survives, recorded here because a refit costs more than it would return. About 4.7% of the human units are markdown residue: a table separator row, or a run of bullets whose `：` outlived the marker `strip_noise` removed. Those units average `link` 0.127 against 0.041 for clean prose, which inflates the fitted human `link` mean by roughly a tenth and narrows that feature's class gap by about as much. It does not reach runtime behavior, since a table payload collapses `pent` to zero and scores strongly human, and a Chinese bullet list measured +1.05 against a floor of 3.04. The judge prompt excludes layout colons by hand instead.

## Measured rates

Read this section before trusting the classifier for anything. Its honest result is that these ratios do not separate clean short Chinese by authorship, and the large numbers below come from two confounds rather than from writing style.

### Clean held-out text

The only clean labelled positives available are the added lines of that one merge request, restricted to the 34 lines `strip_noise` left essentially intact. The negatives are 648 paragraphs of the author's own typed Chinese.

| Version        | AUC   | 95% bootstrap CI |
| -------------- | ----- | ---------------- |
| Adaptive       | 0.548 | [0.456, 0.642]   |
| Fixed centroid | 0.520 | [0.423, 0.623]   |

Both intervals contain 0.5. At the shipped floor, 26.5% of the clean machine paragraphs land above it against 21.0% of the human ones, a likelihood ratio of 1.26. Splitting by length changes nothing: 0.559 at 45–69c, 0.579 at 70–109c, 0.530 above that.

### Where the large numbers come from

The first confound is genre. Grouped 5-fold CV on the essay corpus, `claude-code` against reserve-tier human at ≥45 characters, reports far more:

| Slice    | Adaptive | Fixed centroid | n (assistant / human) |
| -------- | -------- | -------------- | --------------------- |
| overall  | 0.823    | 0.799          | 325 / 676             |
| 45–59c   | 0.706    | 0.651          | 70 / 152              |
| 60–99c   | 0.815    | 0.798          | 148 / 248             |
| 100–199c | 0.869    | 0.845          | 98 / 194              |
| 200c+    | 0.871    | 0.931          | 9 / 82                |

Essays and assistant transcript prose differ in subject and register as well as in authorship, so most of that 0.82 is a classifier telling essays from chat. The 200c+ row reads as a loss and should not be trusted either way, since nine positives put the standard error near 0.1 and the whole 0.06 gap is about half a positive changing rank.

The second confound is `strip_noise` damage, and it inflates the same-medium number specifically. Those presentation notes carry inline code, paths, and table cells, so stripping removes far more from them than from a typed chat message, and the surviving fragments are often incoherent. Score rises monotonically with how much was removed:

| Fraction surviving `strip_noise` | n  | Median score | AUC vs typed |
| -------------------------------- | -- | ------------ | ------------ |
| under 0.70                       | 20 | +2.75        | 0.678        |
| 0.70 to 0.90                     | 50 | +2.47        | 0.659        |
| 0.90 and above                   | 34 | +1.28        | 0.548        |

Measuring across all 104 positives gives 0.63, which is mostly the top two rows. That count exceeds the 99 in the corpus table above because the evaluation re-extracts the merge request straight from its diff, without the per-source cap the corpus build applies. The judge agrees independently: handed the highest-scoring positive in the whole set at +7.79, it returned `ai:false`, because stripping left no locatable symptom in the fragment behind.

### What can be claimed

The adaptive change beats the fixed centroid on every comparison available, and it removes a length bias that demonstrably existed. Neither version demonstrates an ability to detect clean unpolished Chinese at these lengths.

Both comparisons bracket the truth without reaching it. Typed chat messages are probably an unfairly hard negative set, and the essays are certainly an unfairly easy one. Settling it needs human-written prose in the same register as the machine text, and none exists here, since those presentation notes are Claude-generated end to end.

Treat the score as volume reduction on the judge's workload. The judge decides, which is why its prompt requires a symptom it can quote and treats the report as a hint about where to look. Ratio features appear to be out of headroom, so getting further needs a model of the text rather than seven ratios of it.

## Tried and rejected

- **Aggregating short units.** A turn usually edits several lines, so concatenating them should give the ratios a longer sample to stabilize on. Measured across blocks of 1 to 6 contiguous units from one source, aggregation produced no lift at any block size. The first attempt shuffled before blocking and made aggregation look actively harmful, which is an artifact, since shuffling destroys the within-passage repetition `ttr` and `reuse` exist to measure.
- **Dropping the floor below 45 characters.** 45 characters is where the fit stops being valid, and the clean-text results give no reason to expect signal below it. The line that motivated this work is 36 characters and stays out of reach.
- **Genre-conditional means.** Length explains most of the drift genre would have, a genre split needs per-document annotation the corpus does not carry, and the same-medium ceiling leaves nothing for the added parameters to buy.
- **A `gemini` classifier.** Its Chinese sits close enough to human prose that the fit produced no usable separation, so the gate stays inert for it by having no `ASSISTANTS` entry.
- **Replacing inline code with a placeholder.** `strip_noise` now deletes backticked spans, which is correct, since a placeholder inflated `pent` and `ttr` on code-dense prose. It moved discrimination by well under a point of AUC, so it is in for correctness rather than accuracy.

## Rebuilding

There is no committed harness. Fitting needs the author's transcript history and private writing, so it cannot run in CI or on another machine, and a checked-in script would sit there rotting because nobody ever runs it. If the constants need refitting:

1. Harvest paragraphs per class with `strip_noise` and the `admissible` floors applied, tagging each with its source document.
2. Filter assistant transcripts to those older than the model generation being measured.
3. Fit $a$ and $b$ per class per feature by least squares against $\ln n$, forcing $b = 0$ outside `ttr`, `reuse`, and `pent`, then pool the residual deviation across both classes.
4. Validate with K-fold CV split on source document, reporting per-length-band AUC.
5. Recalibrate `SCORE_FLOOR` as the 80th percentile of typed human paragraph scores, then check that the per-paragraph false-positive rate holds as $k$ grows.

Report the same-medium number alongside any in-genre number, or the result will look better than it is.
