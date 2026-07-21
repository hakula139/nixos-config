---
name: read-pdfs
description: Extract, inspect, summarize, or review local PDF files with Poppler text and rendering tools. Use when a user supplies a PDF, asks what a PDF contains, needs page-aware citations, or needs layout, table, image, font, or rendering verification. Handles searchable PDFs directly and image-only or garbled PDFs through rendered page inspection.
---

# Read PDFs

Read local PDFs with the Nix-managed Poppler tools. Keep source documents and extracted content local unless the user explicitly asks to share them.

## Workflow

1. Inspect the document before extraction.

   ```bash
   pdfinfo "$input_pdf"
   pdffonts "$input_pdf"
   ```

   Use `pdfinfo` for page count, page size, metadata, encryption, and PDF version. Use `pdffonts` when missing Unicode mappings or embedded fonts may affect extraction.

2. Extract text in reading order first.

   ```bash
   pdftotext -enc UTF-8 "$input_pdf" -
   ```

   For résumés, tables, multi-column pages, or other layout-sensitive documents, compare the default output with physical-layout output:

   ```bash
   pdftotext -layout -enc UTF-8 "$input_pdf" -
   ```

   Prefer the version that preserves the intended reading order. Do not assume `-layout` is always better for multi-column prose.

   When page-aware citations matter, extract each page with an explicit marker:

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

   Inspect the generated PNGs with the image-viewing tool. Increase to 200 DPI for small text. Render a page range with `-f` and `-l` for long documents.

4. Cross-check material claims against the rendered pages. Text extraction can lose column order, symbols, charts, annotations, and visual hierarchy.

5. Cite page numbers in summaries or reviews when they help the user verify the result. Distinguish document statements from your inferences.

## Failure handling

- If `pdftotext` reports an encryption error, ask the user for the password. Do not attempt to bypass document security.
- If fonts lack usable mappings, use rendered pages. `pdffonts` may show `uni` as `no`; this does not always prevent Poppler from recovering text.
- If a document is scanned, inspect rendered pages directly. Do not install OCR packages or mutate the environment unless the user asks for OCR support.
- If only part of a long document is relevant, use `-f` and `-l` with both `pdftotext` and `pdftoppm`.
- Keep rendered pages and extracted text in a task-specific temporary directory. Remove temporary artifacts after the task when they are no longer useful.

## Scope

This skill covers reading and visual review. For PDF creation, forms, encryption, merging, splitting, or redaction, use a task-specific toolchain and verify the final rendering before delivery.
