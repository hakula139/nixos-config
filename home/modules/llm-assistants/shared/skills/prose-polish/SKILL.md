---
name: prose-polish
description: >-
  Polish, smooth, or restyle Markdown prose in any language with a chosen model, preserving structure,
  code, links, numbers, and quotations. Content changes are out of scope.
---

# Prose Polish

The bundled script is the only way prose is polished here. It sends each eligible paragraph to the model in batches, alongside the whole document as read-only context, and changes only those eligible paragraphs. It rejects rewrites that alter Markdown structure, code spans, links, numbers, or quotations, or that add a banned mark, and retries each rejected rewrite with the reason. A paragraph whose rewrite still fails keeps its original text. Fenced code, front matter, paragraphs that hold indented code, double-backtick spans, or raw code elements, and pieces that are only headings or table rows or hold no letters stay as they are. Skipped pieces produce no report, so polish those yourself.

## Workflow

1. Pick the model. Use the one the user names, or choose one suited to the text, and pass it with `--model`, which takes a key from the model catalog such as `gemini-4-hydrogen`. Without `--model`, the script uses `gemini-4-neon`. [references/evaluation.md](references/evaluation.md) records the blind rewriter reviews and the principles for changing the model or prompts.

2. Run the script. Resolve `<skill-dir>` to this skill's directory.

   - For a draft, run `mktemp`, write the draft with the assistant's file-edit tool to the path it prints, then pass that literal path. The script rewrites the file in place and prints nothing, so read it back and compare it with the draft.

     ```bash
     mktemp
     <skill-dir>/scripts/prose-polish <draft-path>
     ```

   - For a file, pass its path. The script rewrites the file in place and prints nothing, so copy it first and diff the two. It covers every eligible paragraph, including ones the agent did not write.

     ```bash
     before="$(mktemp)"
     cp docs/notes.md "$before"
     <skill-dir>/scripts/prose-polish docs/notes.md
     diff -u "$before" docs/notes.md
     ```

   To preview a file without changing it, feed it through stdin as `< docs/notes.md` and read the output.

   For a long document, run the script in the background and read the result when it finishes, since the total runtime grows with the batch count and any repair rounds.

3. Compare every rewritten paragraph with its original. The checks protect structure and literal material but cannot detect a dropped qualification or a changed claim, so put back any rewrite that does not improve its paragraph.

4. Restore dropped claims with the assistant's file-edit tool, in the polished file or draft. Keep the wording the script produced wherever the claim survives.

5. When a later revision changes part of the polished text, send only the revised fragment back through the script with the same model, then compare the result with that fragment as in step 3. Restoring claims in step 4 is not such a revision.

## Failures

The script exits 1 when the model key is unknown, naming the valid keys, when the model call fails, or when the input cannot be read, whether the path is missing or a directory, or the bytes are not UTF-8 text, on a path or stdin. The file stays untouched in every case. On success it exits 0 and reports on stderr each passage it kept because its rewrite failed a check.
