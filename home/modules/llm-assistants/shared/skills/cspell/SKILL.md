---
name: cspell
description: >-
  Diagnose spelling failures and maintain CSpell dictionaries and local exceptions. Use when adding accepted words, preserving required misspellings, or reviewing spelling configuration.
---

# CSpell

<!-- cspell:ignore legacyrecievevalue recieve -->

Classify each reported token before changing spelling configuration. A passing check should still catch mistakes in authored prose.

## Diagnose before accepting a word

Read the repository's spelling configuration, custom dictionaries, and the reported line in context. Use its pinned CSpell executable and existing check command.

```bash
cspell lint --config cspell.json --no-progress --show-context --show-suggestions path/to/file.md
cspell trace --config cspell.json --ignore-case --only-found candidate
```

Trace searches dictionaries. It does not reproduce filename overrides or identifier splitting, so check the actual file as well. Verify the summary reports files checked. A worktree inside an ignored directory can silently check zero files. Use `--no-gitignore` with explicit file paths when that is the cause.

- Fix new misspellings in authored prose and identifiers when changing them is safe. For a historical API field, compatibility name, or path, inspect callers and migration requirements before renaming it. Suggestions help identify possible corrections but do not establish that a token is a legitimate word.
- Verify unfamiliar names and technical terms against their defining source or official documentation. Inspect identifier boundaries, neighboring uses, and the expected meaning. A token extracted from an APK, generated source, or a dependency can still be an upstream typo.
- Check existing language dictionaries and identifier splitting before accepting fragments of a long name. Do not add every unknown substring returned by a bulk extraction.
- Preserve a known misspelling where changing its exact bytes or identifier would break a contract, compatibility, source citation, path, or evidence record. This can include project-owned names. Use the correct spelling in your explanation and record the source and intended correction where needed to maintain the exception.
- If the classification remains uncertain and affects the result, discuss it with the user before accepting the token.

## Verified vocabulary

Put verified vocabulary that belongs across the project in the existing accepted-word dictionary, usually `.cspell/words.txt`. A rare literal confined to one location can use a local exception. Keep one entry per line, sorted alphabetically without regard to case, and remove case-equivalent duplicates within the edited group.

Use lowercase entries for the normal case-insensitive configuration. For example, `hakula` covers `Hakula` and `HAKULA`, so separate entries are unnecessary. Preserve explicit case-sensitive dictionary requirements when a project has them. Do not rewrite source names to match dictionary casing.

Review the complete dictionary diff. Each addition should have a known meaning and a real checked use. Keep recognized words separate from known misspellings.

## Known typo exceptions

Keep required known misspellings used across files in `.cspell/typos.txt`. Enable it alongside the accepted-word dictionary so shared contracts do not need a list of per-file overrides. A typo confined to one file can use a local exception directly.

```json
{
  "dictionaryDefinitions": [
    {
      "name": "project-words",
      "path": "./.cspell/words.txt",
      "addWords": true
    },
    {
      "name": "known-typos",
      "path": "./.cspell/typos.txt"
    }
  ],
  "dictionaries": ["project-words", "known-typos"]
}
```

Dictionary paths are relative to the configuration file. Leave `addWords` off the typo dictionary so editor additions continue to target accepted vocabulary. Apply the same sorting and duplicate rules to typo entries.

Prefer the full preserved identifier or path token to its misspelled fragments. Verify the actual occurrence with CSpell because recognition and splitting depend on the token and configuration.

For example, use `legacyrecievevalue` to preserve `legacyRecieveValue` as a whole identifier. Adding only `recieve` would also accept that typo in ordinary prose.

If a required cross-file contract is itself a misspelled ordinary word, globally accepting it weakens detection of the same mistake in new prose. Use local exceptions when the word remains confined to one file. Otherwise, preserve the contract and review authored prose for accidental uses. A typo's origin does not determine whether it belongs in this dictionary. The contract and where it is used do.

## Local exceptions

For a literal confined to one file, put the local directive in that file. Use a filename override with `ignoreWords` only when the format cannot carry comments without changing the data, or a concrete configuration constraint requires it. Keep the reason beside an exception when the literal's purpose is otherwise unclear.

- For one line containing an intentional spelling or opaque literal, `cspell:disable-line` suppresses that entire line. Inspect other words on the line before using it. In Markdown, an inline HTML comment keeps the directive out of rendered prose.
- `cspell:disable-next-line` suppresses the next content line. Place the directive immediately above its target, with no intervening blank line by default. Preserve a blank line when the formatter requires one. CSpell 9.7.0 supports this layout, but verify behavior with the project's pinned version.
- `cspell:ignore` permits the listed tokens throughout the file. Use it when those exact tokens need file-wide acceptance and surrounding words should remain checked.
- For known typos required across files, use `.cspell/typos.txt` globally. For recurring legitimate vocabulary across the project, use the accepted-word dictionary.

```markdown
### recieve <!-- cspell:disable-line -->

<!-- cspell:disable-next-line -->
`legacyRecieveValue`
```

The spelling in this example is intentionally preserved. A line directive also suppresses unrelated mistakes on that line, so prefer a token-level file exception or an exact literal pattern when nearby authored prose still needs checking. A file-level exception allows the same token elsewhere in that file, which also needs review.

Language dictionaries can cover real foreign-language text. Exclusions for generated files, code samples, mathematics, or markup require an ownership reason. Source identifiers under investigation often need spelling checks even inside code spans. Check which content the spelling check owns before copying broad code or comment exclusions. Keep exclusions tied to that ownership and avoid patterns that suppress arbitrary identifiers.

## Verify the boundary

Run the affected checks after editing. For a new full-identifier dictionary entry, use disposable fixtures to prove that the preserved identifier passes across files while its misspelled fragment and an unrelated typo still fail in ordinary prose. For a local exception, verify its intended scope and check that unrelated words remain checked. If a globally accepted entry is a misspelled ordinary word, report that it also passes in new prose and review those occurrences manually. Require a nonzero checked-file count for each control.

Review dictionary entries, override matches, and surrounding prose together. A successful check does not validate the meaning of newly accepted words.

Configuration details: [custom dictionaries](https://cspell.org/docs/dictionaries/custom-dictionaries), [overrides](https://cspell.org/docs/Configuration/overrides), and [case sensitivity](https://cspell.org/docs/case-sensitive).
