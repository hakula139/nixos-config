---
name: cspell
description: >-
  Diagnose spelling failures and maintain CSpell dictionaries and scoped exceptions. Use when adding accepted words, preserving upstream misspellings, or reviewing spelling configuration.
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

- Fix authored misspellings in the source. Suggestions help identify possible corrections but do not establish that a token is a legitimate word.
- Verify unfamiliar names and technical terms against their defining source or official documentation. Inspect identifier boundaries, neighboring uses, and the expected meaning. A token extracted from an APK, generated source, or a dependency can still be an upstream typo.
- Check existing language dictionaries and identifier splitting before accepting fragments of a long name. Do not add every unknown substring returned by a bulk extraction.
- Preserve an upstream misspelling only where its exact bytes or identifier are needed for an API contract, source citation, path, or evidence record. Use the correct spelling in your explanation.
- If the classification remains uncertain and affects the result, discuss it with the user before accepting the token.

## Accepted words

Put verified project vocabulary in the existing accepted-word dictionary, usually `.cspell/words.txt`. Keep one entry per line, sorted alphabetically without regard to case, and remove case-equivalent duplicates within the edited group.

Use lowercase entries for the normal case-insensitive configuration. For example, `hakula` covers `Hakula` and `HAKULA`, so separate entries are unnecessary. Preserve explicit case-sensitive dictionary requirements when a project has them. Do not rewrite source names to match dictionary casing.

Review the complete dictionary diff. Each addition should have a known meaning and a real checked use. Keep recognized words separate from known upstream misspellings.

## Upstream typo exceptions

Keep required upstream misspellings in a separate dictionary such as `.cspell/typos.txt`. Define it alongside the accepted-word dictionary, then enable it only for the smallest set of files that needs those literals:

```json
{
  "dictionaryDefinitions": [
    {
      "name": "project-words",
      "path": "./.cspell/words.txt",
      "addWords": true
    },
    {
      "name": "upstream-typos",
      "path": "./.cspell/typos.txt"
    }
  ],
  "dictionaries": ["project-words"],
  "overrides": [
    {
      "filename": "docs/reference/vendor-symbols.json",
      "dictionaries": ["upstream-typos"]
    }
  ]
}
```

Adapt the filename to the actual evidence owner. Dictionary paths are relative to the configuration file. Leave `addWords` off the typo dictionary so editor additions continue to target accepted vocabulary. Apply the same sorting and duplicate rules to typo entries.

A filename override permits those tokens throughout each matching file. When a document mixes evidence with substantial authored prose, prefer an exact literal pattern or a line directive supported by the project's CSpell version. Record the upstream source and intended correction where they help maintain the exception. Avoid broad directory overrides, whole-document disabling, and patterns that suppress arbitrary identifiers. Keep generated output and lockfile exclusions tied to actual file ownership.

## Verify the boundary

Run the affected checks after editing. For a new exception, use disposable fixtures to prove that the required upstream literal passes in its intended scope and the same typo still fails in ordinary authored prose. Also check that a different misspelling still fails inside the exception's scope. Require a nonzero checked-file count for each control.

Review dictionary entries, override matches, and surrounding prose together. A successful check does not validate the meaning of newly accepted words.

Configuration details: [custom dictionaries](https://cspell.org/docs/dictionaries/custom-dictionaries), [overrides](https://cspell.org/docs/Configuration/overrides), and [case sensitivity](https://cspell.org/docs/case-sensitive).
