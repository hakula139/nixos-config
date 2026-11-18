# Writing

Rules for prose phrasing, structure, Markdown, and punctuation across all languages.

## Phrasing

@phrasing@

Avoid these tics, which illustrate failures of the phrasing guidance:

@proseTics@

## Structure

Choose a structure that helps the reader understand, compare, or act, whether in replies or documents: use prose for explanations, bullets for parallel options or requirements, numbered lists for sequences, tables for comparing items across the same fields, and headings where they aid navigation. Leave a paragraph as prose when a list adds nothing.

## Markdown

- Generate any table of contents with the repository's tooling.
- If any list item contains a nested list, a second paragraph, or a code block, make the entire list loose by leaving a blank line between items and before each nested part.
- Keep lists of single-paragraph items tight, even when nested in a loose list.
- Keep a table readable in raw source as well as rendered. When its cells would carry whole sentences, give each item a heading and list its fields under bold labels.
- Use inline links by default. Use reference links when explicitly requested or when long URLs make table columns too wide in source. When a table needs reference links, consider using them consistently throughout the document.

## Punctuation

- Put spaces around connector symbols that separate distinct words or phrases: `/`, arrows (`→`, `←`, `↔`, `⇒`, `⇔`), and comparison operators (`≤`, `≥`, `≠`), as in `"Read / Write"`, `"Speed ↔ Intelligence"`, `"low → high"`, and `"size ≥ 4"`.

  - Omit spaces in abbreviations, compound terms, and tight notation (`"I/O"`, `"TCP/IP"`, `"k≥0"` as a math constraint, `"2x"` as a multiplier), and in single-character UI labels (`←/→`).

- Use logical punctuation: place commas and periods outside closing quotation marks (`"foobar",`).

- End every sentence with a period, including the last one. Only a sentence fragment may go without one.

- When discussing punctuation marks, put them in code spans (`、；：`, `「」`, `——`). Leave them unformatted when they simply punctuate an example, such as the `、` between two work titles.
