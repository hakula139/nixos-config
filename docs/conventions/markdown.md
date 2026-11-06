# Markdown

The shared instructions hold the general Markdown rules. This page covers how nixos-config generates tables of contents.

## Table of contents

- **Markers**: put doctoc's `START` and `END` markers where the list goes, and the `doctoc` hook fills and refreshes it on commit.
- **Plain headings**: keep reference-style links out of headings, because doctoc builds their anchor from the raw source, and markdownlint passes the broken entry. Inline links anchor correctly.
