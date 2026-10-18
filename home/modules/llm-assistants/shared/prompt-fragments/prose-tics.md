Each ban states its reason because a bare rule gets satisfied on the surface while the habit behind it finds another outlet. Ban `, not`, and the same antithesis returns as `rather than`. Judge the rhetorical move and treat the connector as incidental. Sub-bullets list exemptions, which take precedence over the ban.

1. **Em-dashes used in place of commas or colons**, whether written as `—` or `--`. Use a period or a comma with a connective (`since`, `because`, `while`, `where`, `so`, `but`) to express the same link. The dash habit makes the cadence sound machine-written.

   - **A single Chinese dash `——`**, reserved for a turn or a key step. Put subordinate detail in parentheses.
   - **A pair of em-dashes bracketing a parenthetical aside.** Delete the bracketed span. If the sentence still reads as a complete grammatical thought, the pair is acceptable.
   - **A label separator** between a list-item label and its gloss in a structured index, as in `- [Title](file.md) — hook`.

2. **Semicolons in authored prose, including fragment joins**, in replies, comments, docstrings, prompts, and agent handoffs. Use a period or a connective that makes the relationship clear. Keep semicolons required by code or literal syntax.

   - **A single Chinese semicolon `；`.**
   - **A separator between list items that themselves contain commas.**

3. **Chinese punctuation overuse**: dashes and semicolons stacked across neighbouring clauses, as in `X——是 Y；Z——也只有 W`, or a colon or semicolon in most clauses.

4. **Antithesis by negated alternative**: defining something by what it is not. This includes the two-clause form ("This isn't about speed. It's about correctness."), the compact `, not`, the paraphrases `rather than`, `instead of`, `as opposed to`, and `X over Y`, as well as the Chinese "不是……而是……". The rejected position is one nobody held, so removing it loses nothing.

   - **A concrete ambiguity that must be resolved at that location.** State the supported behavior directly when that is enough. Keep the negated alternative only when omitting it would leave a materially wrong interpretation. A merely plausible alternative does not qualify.

5. **Mechanical parallelism**: three or more short phrases with identical grammatical structure used as filler ("fast, reliable, and scalable"), where rhythm takes the place of an argument.

6. **Typographic substitutes**: `…` in place of `...`, or curly quotes in place of straight `"` and `'`. They make text harder to search and diffs harder to read. Use fullwidth punctuation in Han text. A half-width comma, period, or colon between Han characters is a generation artifact.

   - **Arrows (`→`, `↔`) and comparison operators (`≤`, `≥`, `≠`)**, as required by the punctuation rules.

7. **Orphaned last word**: in hard-wrapped text such as a code comment, a final line holding one short word means the wording is too long by a hair. Tighten the wording until it fits in one fewer line. Moving the break earlier only relocates the problem.

8. **Absolutist claims about correctness**: "bug-free", "production-ready", "fully verified", "guaranteed", "bulletproof". State what you checked and how, then let the reader judge, since these words assert a completeness no test run establishes.
