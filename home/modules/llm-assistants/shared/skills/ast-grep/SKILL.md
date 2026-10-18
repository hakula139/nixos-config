---
name: ast-grep
description: >-
  Search and rewrite code by syntax tree with the ast-grep CLI. Use when a match depends on code
  structure, such as call shapes, arguments, or nesting, that text search would over- or
  under-match, or when one mechanical change spans many files.
---

# ast-grep

ast-grep matches tree-sitter patterns against the syntax tree, so whitespace and line breaks do not affect a match, and code inside comments or strings never matches. Use the harness's native structural search or edit tool instead when one exists.

Run `ast-grep`, never `sg`, which is shadow's group command on these hosts.

## Choosing a tool

- `rg` for identifiers, literals, comments, configuration, prose, and file types ast-grep cannot parse. It is faster and easier to scan.
- ast-grep for syntax questions, such as every call of `foo` with two arguments, `await` inside a loop, or a pattern that formatting splits across lines.
- The editor tool for a few edits or edits that each need judgment, and an ast-grep rewrite for one uniform change across many sites.

## Search

```bash
ast-grep run -p 'console.log($ARG)' -l ts src/
ast-grep run -p 'foo($$$ARGS)' -l ts --json=stream . | jq -r '"\(.file):\(.range.start.line + 1)"'
```

- A pattern must parse as code in the target language. `-l` fixes that language and limits the search to its extensions, so `-l ts` skips `.tsx` and `.js`. Across languages, run once per language, or omit `-l` to parse the pattern in each file's own language. `--debug-query` requires `-l`.
- `$NAME` matches exactly one node, `$$$NAME` zero or more, and `$_` one node without capturing it. A reused name requires identical text, so `$A == $A` matches `x == x` but not `x == y`.
- A pattern matches whole nodes. `foo($ARG)` misses `foo(a, b)` and `obj.foo(a)`, so zero matches can mean a wrong shape. Test the pattern on a snippet known to contain the target.
- Inspect node kinds with `--debug-query=ast`, and how the pattern itself parsed with `--debug-query=pattern`.
- Searches respect `.gitignore` and skip hidden files. Include them with `--no-ignore vcs` or `--no-ignore hidden`, and narrow with paths or `--globs '!**/generated/**'`.
- `run` exits 1 when nothing matches, which is not an error.

## Rule files

Use a YAML rule when a pattern alone cannot express the query, keeping scratch rules outside the repository, for example in a `mktemp -d` directory.

```yaml
id: await-in-for
language: TypeScript
rule:
  pattern: await $CALL
  inside:
    kind: for_statement
    stopBy: { kind: arrow_function }
```

```bash
ast-grep scan --rule "$rule_dir/await-in-for.yml" src/
```

- Combine conditions with `all`, `any`, and `not`. Relational keys (`inside`, `has`, `precedes`, `follows`) inspect only the adjacent node by default. `stopBy: end` searches every ancestor, descendant, or sibling in that direction, and a `stopBy` rule stops at the first node it matches, as the example does at an arrow function so an `await` in a callback defined inside the loop is not reported.
- Match a fragment that does not parse alone, such as an object key, with `pattern: { context: '({ timeout: $V })', selector: pair }`.
- Filter captures with `constraints`, for example `constraints: { NAME: { regex: '^use' } }`.
- `ast-grep scan` without `--rule` or `--inline-rules` needs an `sgconfig.yml` project and otherwise exits 3.

## Rewrite

Shell rewrites bypass the editor tools' hooks, including auto-formatting and comment checks, and Claude Code checkpoints cannot roll them back. Treat every rewrite as an unreviewed bulk edit.

1. Run `git status --short`. On a clean tree, `git diff` shows only the rewrite and `git restore` undoes it. Uncommitted changes may belong to the user or another agent, so never stash, commit, or restore them, and exclude their files with `--globs '!<path>'` so restoring the rewrite cannot discard them.

2. Preview the change. `-r` on `run`, or a `fix` key in a rule, prints a diff and writes nothing.

   ```bash
   ast-grep run -p 'console.log($$$ARGS)' -r 'logger.info($$$ARGS)' -l ts src/
   ```

3. Read every hunk, and narrow the paths, globs, or pattern until the preview holds only intended changes.

4. Apply the reviewed command unchanged apart from `-U` (`--update-all`). Avoid `-i`, which needs an interactive terminal.

5. Review `git diff` for the rewritten files, then run the project's formatters, linters, and tests on them, since ast-grep does not reformat its output.

Keep each rewrite to one logical change, with separate runs and previews for unrelated transformations. For changes that need type or reference information, such as renaming a symbol with overloads or shadowing, prefer the language server or the language's refactoring tool.
