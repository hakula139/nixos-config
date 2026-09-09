---
name: browser-debugging
description: Use Nix-managed Playwright and browsers to debug web pages, inspect rendering or scrolling performance, and capture screenshots. Applies when browser automation needs the shared Nix environment.
---

# Browser Debugging

Locate the local `nixos-config` checkout, using the task's worktree when changing its browser infrastructure. Its `browser` dev shell includes the default shell's development and checking tools plus the Playwright CLI, Node.js, Python Playwright, Chromium, Firefox, and WebKit. It does not install repository Git hooks in the current project.

Run browser commands in that profile without changing the working directory:

```bash
nix develop /absolute/path/to/nixos-config#browser -c python3 /tmp/browser-check.py
```

For an interactive session, use `nix develop /absolute/path/to/nixos-config#browser`. Inside the configuration checkout, the shorter reference is `.#browser`.

Use the profile's Python Playwright API for standalone debugging scripts. Launch headless browsers by default, select Firefox or WebKit when cross-engine coverage matters, and capture screenshots for visual changes. Wait for the relevant DOM state before measuring or capturing.

The profile scopes `PLAYWRIGHT_BROWSERS_PATH` to its matching Nix browsers and does not set `NODE_PATH`. It needs no `playwright install`. For a project's own Node Playwright dependency, use the project's environment and matching browser revisions. Mixing that dependency with this profile's browser path can fail when revisions differ.

Configured Chrome DevTools MCP, Scrapling MCP, and agent-browser already receive the shared Chromium executable and do not require this dev shell. Use their available capabilities directly when they fit the task.

Headless measurements establish behavior in the tested environment. For scrolling or blur performance, inspect rendering traces and GPU status before attributing a slowdown to acceleration, and distinguish headless results from the user's desktop browser.
