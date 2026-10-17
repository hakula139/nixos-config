---
name: read-pdfs
description: >-
  Read or review local PDFs with Poppler text extraction and page rendering. Use for PDF summaries,
  page citations, layout checks, or scanned and garbled documents that need visual inspection.
---

# Read PDFs

Read local PDFs with Poppler, keeping source documents and extracted content local unless the user asks to share them. Development hosts install `poppler-utils`. Elsewhere, prefix the commands below with `nix shell nixpkgs#poppler-utils -c`.

## Workflow

1. Inspect the document with `pdfinfo "$input_pdf"` for page count, page size, metadata, encryption, and PDF version. Run `pdffonts "$input_pdf"` when missing Unicode mappings or embedded fonts may affect extraction.

2. Extract text in reading order.

   ```bash
   pdftotext -enc UTF-8 "$input_pdf" -
   ```

   For résumés, tables, multi-column pages, or other layout-sensitive documents, compare it with `pdftotext -layout`, and keep whichever preserves the intended reading order, since `-layout` can break multi-column prose.

   When page citations matter, extract each page behind a marker:

   ```bash
   page_count="$(pdfinfo "$input_pdf" | awk '/^Pages:/ { print $2 }')"
   for page in $(seq 1 "$page_count"); do
     printf '\n--- page %s ---\n' "$page"
     pdftotext -f "$page" -l "$page" -enc UTF-8 "$input_pdf" -
   done
   ```

3. Render pages when layout or visuals matter, or when extracted text is empty, incomplete, or garbled.

   ```bash
   render_dir="$(mktemp -d)"
   pdftoppm -png -r 150 "$input_pdf" "$render_dir/page"
   ```

   Inspect the PNGs with the image-viewing tool, raising the resolution to 200 DPI for small text.

4. Cross-check material claims against the rendered pages, because extraction can lose column order, symbols, charts, annotations, and visual hierarchy.

5. Cite page numbers where they help the user verify the result, and distinguish the document's statements from your inferences.

## Failure handling

- On an encryption error, ask the user for the password, and never try to bypass document security.
- When fonts lack usable mappings, read the rendered pages. `pdffonts` may show `uni` as `no` even when Poppler still recovers the text.
- For a scanned document, inspect the rendered pages directly, and install OCR packages or change the environment only when the user asks for OCR.
- If only part of a long document is relevant, limit both `pdftotext` and `pdftoppm` to those pages with `-f` and `-l`.
- Keep rendered pages and extracted text in a task-specific temporary directory, and remove them when they are no longer useful.

## Scope

This skill covers reading and visual review. For PDF creation, forms, encryption, merging, splitting, or redaction, use a task-specific toolchain and verify the final rendering before delivery.
