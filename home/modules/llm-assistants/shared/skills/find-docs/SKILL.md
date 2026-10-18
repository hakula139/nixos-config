---
name: find-docs
description: >-
  Look up current documentation and examples with Context7. Use whenever a task depends on a
  library, framework, SDK, CLI tool, or cloud service's APIs, configuration, setup, migration, or
  version-specific behavior. Prefer this to web search for developer documentation.
---

# Find Docs

Verify library-specific details against current documentation, even for familiar APIs. Use the managed `ctx7` command, which loads its API key at launch.

## Resolve the library

```bash
ctx7 library <name> "<focused documentation question>"
```

Resolve the name before querying docs unless the user supplies a Context7 ID such as `/org/project` or `/org/project/version`. Include the package's official name and the relevant API or behavior in the query to distinguish similarly named projects. Choose by project identity, documentation relevance, and source reputation. Snippet counts and benchmark scores help compare otherwise suitable results.

Use a version-specific ID from the returned versions when the task targets that version. If it is unavailable, say which version the available documentation covers and verify compatibility against the project's official versioned docs. Do not invent an ID or silently treat another version as equivalent. Ask when the intended project or version remains materially ambiguous.

## Query and verify

```bash
ctx7 docs <libraryId> "<focused documentation question>"
```

Keep each query focused on one topic, or on the interaction the question asks about. Send only the public names and behavior needed for retrieval, excluding credentials, personal data, and proprietary code.

Read the returned snippets and their source links, checking that the documented signatures and behavior apply to the target version and surrounding code. Follow the official source when the snippets omit a relevant constraint or conflict. Link the authoritative documentation supporting the answer and distinguish documented behavior from inference.

## Missing results and failures

Refine the library name or question when results are irrelevant. If Context7 lacks the needed coverage, use available web search or fetch tools to read the project's official documentation or source. Report a quota, authentication, or service failure clearly and use the same fallback. The managed environment supplies authentication, so logging in does not replace its credential.

If no source can be reached, state the verification gap and identify any answer based on prior knowledge as potentially outdated.
