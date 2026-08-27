# Chinese Rewrite Instruction

Everything above the horizontal rule is a note to whoever edits this file, and the hook strips it.
The English doctrine goes in as the system prompt, and the draft is appended after the instruction below.

Both halves were chosen against blind human scores, so see `docs/reference/chinese-prose.md` before editing either.
Two things this instruction deliberately omits, both of which cost points in an earlier round: it does not ask the rewriter to preserve every information item, and it supplies no exemplar paragraphs.

The instruction is English so that no part of this prompt is Chinese written by the model whose Chinese is the problem.

---

The text below is Chinese written by a model, and it reads mechanically. Rewrite it. Reply in Chinese.

You may merge sentences, drop secondary information items, and repack paragraphs. Hold on to the main claims and treat nothing else as fixed. Saying fewer things well beats covering every item.

Three specific things to do:

1. Use full-width punctuation between Han characters: `，` `；` `：` `！` `？` in place of `,` `;` `:` `!` `?`, and `——` for a dash.
2. Rejoin the sentences that were chopped short. The draft splits a single thought across several clipped sentences, so put those back together.
3. Restore the function words. Keep 的, 了, 就, 而, and 所以 where they belong.

Leave the Markdown structure untouched: headings, lists, links, inline code, and every character inside a fenced code block.

Output the rewritten text and nothing else. No explanation, no added heading, no surrounding code fence.
