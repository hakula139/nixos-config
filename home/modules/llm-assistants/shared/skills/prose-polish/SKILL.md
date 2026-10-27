---
name: prose-polish
description: >-
  Polish the style of prose in a Markdown file or draft with a chosen model, in any language, under
  fidelity checks that keep structure, code, links, numbers, and quotations intact. Use when asked to
  polish, smooth, or restyle prose, or to polish with a specific model such as Gemini 3.8 Flash.
  Content changes are out of scope, since the rewriter may add no claims.
---

# Prose Polish

The bundled script is the only way prose is polished here. It sends each eligible paragraph to the model. It rejects rewrites that alter Markdown structure, code spans, links, numbers, or quotations, or that add a banned mark, and retries each rejected rewrite with the reason. A paragraph whose rewrite still fails keeps its original text. Fenced code, front matter, paragraphs that hold indented code, double-backtick spans, or raw code elements, and pieces that are only headings or table rows or hold no letters stay as they are. Skipped pieces produce no report, so polish those yourself.

## Workflow

1. Pick the model. Use the one the user names, or choose one suited to the text, and pass it with `--model`, which takes a key from the model catalog such as `gemini-3.8-flash`. Without `--model`, the script uses `gemini-4-argon`.

2. Run the script. Resolve `<skill-dir>` to this skill's directory.

   - For a draft, pipe it in and capture the result outside the repository.

     ```bash
     polished="$(mktemp)"
     <skill-dir>/scripts/prose-polish > "$polished" <<'EOF'
     ...
     EOF
     ```

   - For a file, pass its path. The script rewrites the file in place and prints nothing, so copy it first and diff the two. It covers every eligible paragraph, including ones the agent did not write.

     ```bash
     before="$(mktemp)"
     cp docs/notes.md "$before"
     <skill-dir>/scripts/prose-polish docs/notes.md
     diff -u "$before" docs/notes.md
     ```

   To preview a file without changing it, feed it through stdin as `< docs/notes.md` and read the output.

3. Compare every rewritten paragraph with its original. The checks protect structure and literal material but cannot detect a dropped qualification or a changed claim, so put back any rewrite that does not improve its paragraph.

4. Restore dropped claims with the assistant's file-edit tool, in the polished file or draft. Keep the wording the script produced wherever the claim survives.

## Failures

The script exits 1 when the model key is unknown, naming the valid keys, when the model call fails, or when the input cannot be read, whether the path is missing or a directory, or the bytes are not UTF-8 text, on a path or stdin. The file stays untouched in every case. On success it exits 0 and reports on stderr each passage it kept because its rewrite failed a check. A long document can exceed one call's time or output limit, which also fails the model call, so polish it in sections.
