---
name: browser-debugging
description: Investigate web UI failures, visual regressions, and browser performance. Use for browser testing, Playwright scripts, screenshots, console or network inspection, and cross-browser reproduction.
---

# Browser Debugging

## Choose the tool

Reuse available browser tooling before installing Playwright or downloading browser binaries.

- For interactive navigation and page inspection, use agent-browser and follow its skill when available.
- For performance traces, console errors, and network diagnostics, use Chrome DevTools MCP.
- For reproducible scripts or Chromium / Firefox / WebKit comparisons, use Python Playwright in the shared browser profile.

## Run standalone automation

Write a Python Playwright script and run it with the managed browsers:

```bash
nix develop nixos-config#browser -c python3 /tmp/browser-check.py
```

The profile supplies matching Python Playwright and browser binaries. Launch headless by default, choosing Firefox or WebKit when the issue calls for another engine.

Run project-owned Playwright suites in their project environment with the browser revisions required by their dependency version. The profile's `PLAYWRIGHT_BROWSERS_PATH` is paired with its bundled driver.

When modifying the browser profile itself, run `nix develop .#browser` from the configuration worktree to test the local changes.

## Gather evidence

Reproduce the reported interaction at the relevant viewport and device scale. Wait for the relevant content to render, then inspect the DOM and screenshots. Compare visual changes under the same conditions and inspect the resulting images yourself.

For performance issues, capture a trace while reproducing the interaction. Check scripting, layout, paint, and compositing costs, then inspect GPU status when acceleration is a suspected cause. Record the browser engine, headless mode, and rendering backend with measurements so differences from the user's desktop browser remain visible.
