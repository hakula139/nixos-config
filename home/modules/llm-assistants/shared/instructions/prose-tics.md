Each ban carries its reason. A rule given without one gets satisfied on the surface while the habit behind it finds another outlet, which is why banning a connector only moves the problem: forbid `, not` and the same antithesis comes back as `rather than`. Judge the rhetorical move, and treat the connector as incidental.

Every ban has a sub-bullet slot for its exemptions. An exemption outranks the ban.

1. **Em-dash standing in for a comma or a colon**, as the `—` character or as `--`. Most of the time a period or a transition word (`since`, `because`, `while`, `where`, `so`, `but`) plus a comma carries the same link and reads better, and reaching for the dash instead is what makes the cadence read as machine-written.
   - **A pair bracketing a parenthetical aside.** Delete the bracketed span. If the sentence still reads as a complete grammatical thought, the em-dashes mark an aside and pass.
   - **A label separator** between a list-item label and its gloss, as in `- [Title](file.md) — hook`, which is a field separator in a structured index.
2. **Semicolons in authored prose, including fragment joins.** Use a period or a connecting word that states the relationship. This applies to replies, comments, docstrings, prompts, and agent handoffs. Preserve semicolons required by code or literal syntax.
   - **A separator between list items that themselves contain commas**, where it is structural.
3. **Antithesis by negated alternative**: defining something by what it is not. The two-clause form ("This isn't about speed. It's about correctness."), the compact `, not` form, and the paraphrases `rather than`, `instead of`, `as opposed to`, and `X over Y` all count, as does the Chinese "不是……而是……". The clause spends a sentence on a position nobody held, so deleting it and keeping the assertion loses nothing.
   - **A concrete ambiguity that must be resolved at that location.** State the supported behavior directly whenever that is sufficient. Use a negated alternative only when omitting it would leave the reader with a materially wrong interpretation. A plausible alternative alone does not justify the contrast.
4. **Mechanical parallelism**: three or more short phrases of identical grammatical structure used as filler ("fast, reliable, and scalable"). The symmetry reads as rhythm standing in for an argument.
5. **Typographic substitutes**: `…` where three periods `...` belong, or curly quotes where the straight `"` and `'` belong. They break text search and clean diffs for no gain.
   - **Arrows (`→`, `↔`) and comparison operators (`≤`, `≥`, `≠`)**, which the punctuation convention calls for.
6. **Orphaned last word**: in hard-wrapped text such as a code comment, a final line holding one short word means the wording is too long by a hair. Tighten or rephrase until the whole thing fits one fewer line. Moving the break earlier only relocates the problem.
7. **Absolutist claims about correctness**: "bug-free", "production-ready", "fully verified", "guaranteed", "bulletproof". State what was checked and by what means, then let the reader judge, since these words assert a completeness no test run establishes.
