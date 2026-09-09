---
name: browser-debugging
description: Debug and test web pages with browser automation. Use for Playwright tests, screenshots, visual regressions, console or network inspection, scrolling and rendering performance, and Chromium / Firefox / WebKit checks.
---

# Browser Debugging

Check the existing browser tooling before installing Playwright or downloading browser binaries. Use configured Chrome DevTools MCP, Scrapling MCP, or agent-browser when their capabilities fit the task. They already receive the shared Chromium executable. For standalone automation, use the browser profile below.

The managed Nix registry names the deployed configuration `nixos-config`, so no checkout path is needed. Its `browser` dev shell includes the default shell's development and checking tools plus the Playwright CLI, Node.js, Python Playwright, Chromium, Firefox, and WebKit. It does not install repository Git hooks in the current project.

Run browser commands in that profile without changing the working directory:

```bash
nix develop nixos-config#browser -c python3 /tmp/browser-check.py
```

For an interactive session, use `nix develop nixos-config#browser`. When changing browser infrastructure in a `nixos-config` worktree, use `.#browser` there to test the working tree instead of the deployed version.

Use the profile's Python Playwright API for standalone debugging scripts. Launch headless browsers by default, select Firefox or WebKit when cross-engine coverage matters, and capture screenshots for visual changes. Wait for the relevant DOM state before measuring or capturing.

The profile scopes `PLAYWRIGHT_BROWSERS_PATH` to its matching Nix browsers and does not set `NODE_PATH`. It needs no `playwright install`. For a project's own Node Playwright dependency, use the project's environment and matching browser revisions. Mixing that dependency with this profile's browser path can fail when revisions differ.

Headless measurements establish behavior in the tested environment. For scrolling or blur performance, inspect rendering traces and GPU status before attributing a slowdown to acceleration, and distinguish headless results from the user's desktop browser.
