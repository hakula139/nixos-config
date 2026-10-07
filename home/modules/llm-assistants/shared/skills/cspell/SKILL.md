---
name: cspell
description: >-
  Diagnose spelling failures and maintain CSpell dictionaries and scoped exceptions. Use when adding accepted words, preserving required misspellings, or reviewing spelling configuration.
---

# CSpell

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

Keep required known misspellings in a separate dictionary such as `.cspell/typos.txt`. Define it alongside the accepted-word dictionary, then enable it only for the smallest set of files that needs those literals:

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
  "dictionaries": ["project-words"],
  "overrides": [
    {
      "filename": "docs/reference/vendor-symbols.json",
      "dictionaries": ["known-typos"]
    }
  ]
}
```

Adapt the filename to the actual evidence owner. Dictionary paths are relative to the configuration file. Leave `addWords` off the typo dictionary so editor additions continue to target accepted vocabulary. Apply the same sorting and duplicate rules to typo entries.

A filename override permits those tokens throughout each matching file. Keep the filename set narrow and review prose in each matched file for accidental uses of the same typo. A typo's origin does not determine whether it belongs in this dictionary. The contract requiring preservation does.

## Local exceptions

Choose the smallest scope that covers the actual use. Keep the reason beside an exception when the literal's purpose is otherwise unclear.

- For one line containing an intentional spelling or opaque literal, `cspell:disable-line` suppresses that entire line. Inspect other words on the line before using it. In Markdown, an inline HTML comment keeps the directive out of rendered prose.
- `cspell:disable-next-line` suppresses the next content line. CSpell 9.7.0 also skips an intervening blank line. Keep the directive adjacent to its target for readability, and verify behavior with the project's pinned version.
- `cspell:ignore` permits the listed tokens throughout the file. Use it when those exact tokens need file-wide acceptance and surrounding words should remain checked. A filename override with `ignoreWords` provides the same intended file-level scope through configuration when repeated literals justify central ownership.
- For repeated known typos in a small set of contract or evidence files, use the separate typo dictionary and narrow overrides above. For recurring legitimate vocabulary across the project, use the accepted-word dictionary.

```markdown
### recieve <!-- cspell:disable-line -->
```

The spelling in this example is intentionally preserved. A line directive also suppresses unrelated mistakes on that line, so prefer a token-level file exception or an exact literal pattern when nearby authored prose still needs checking. A file-level exception allows the same token elsewhere in that file, which also needs review.

Language dictionaries can cover real foreign-language text. Exclusions for generated files, code samples, mathematics, or markup require an ownership reason. Source identifiers under investigation often need spelling checks even inside code spans. Avoid blanket code or comment exclusions, broad directory overrides, whole-document disabling, and patterns that suppress arbitrary identifiers.

## Verify the boundary

Run the affected checks after editing. For a new exception, use disposable fixtures to prove that the required preserved literal passes in its intended scope and the same typo still fails in ordinary authored prose. Also check that a different misspelling still fails inside the exception's scope. Require a nonzero checked-file count for each control.

Review dictionary entries, override matches, and surrounding prose together. A successful check does not validate the meaning of newly accepted words.

Configuration details: [custom dictionaries](https://cspell.org/docs/dictionaries/custom-dictionaries), [overrides](https://cspell.org/docs/Configuration/overrides), and [case sensitivity](https://cspell.org/docs/case-sensitive).
