---
name: ast-grep
description: >-
  Search and rewrite code by syntax tree with the ast-grep CLI. Use when a match depends on code
  structure, such as call shapes, arguments, or nesting, that text search would over- or
  under-match, or when one mechanical change spans many files.
---

# ast-grep

ast-grep parses source files with tree-sitter and matches patterns against the syntax tree, so whitespace and line breaks do not affect a match, and code inside comments or strings never matches. If your harness already provides a native structural search or edit tool, use that tool instead.

Invoke the binary as `ast-grep`. The nixpkgs package ships no `sg` alias, and `sg` on these hosts resolves to shadow's group-switching command, so translate any `sg` command that ast-grep's own messages suggest. The home configuration installs ast-grep on development hosts. If `ast-grep` is not on `PATH`, prefix the commands below with `nix shell nixpkgs#ast-grep -c` to run them without changing the host configuration.

## Choosing a tool

- Use `rg` for identifiers, literals, comments, configuration, prose, and any file type ast-grep cannot parse. It is faster and its results are easier to scan.
- Use ast-grep when the question is about syntax: every call of `foo` with two arguments, `await` inside a loop, or a pattern that formatting splits across lines.
- Use the editor tool for a few edits or edits that each need judgment. Use an ast-grep rewrite for one uniform change across many sites.

## Search

```bash
ast-grep run -p 'console.log($ARG)' -l ts src/
ast-grep run -p 'foo($$$ARGS)' -l ts --json=stream . | jq -r '"\(.file):\(.range.start.line + 1)"'
```

- A pattern must parse as code in the target language. `-l` fixes that language and limits the search to its file extensions, so `-l ts` skips `.tsx` and `.js` files. When the target spans languages, run once per language, or omit `-l` to parse the pattern in each file's own language. `--debug-query` requires `-l`.
- `$NAME` matches exactly one node, `$$$NAME` matches zero or more, and `$_` matches one node without capturing it. Reusing a name requires identical text, so `$A == $A` matches `x == x` but not `x == y`.
- A pattern matches whole nodes. `foo($ARG)` misses `foo(a, b)` and `obj.foo(a)`, so zero matches can mean a wrong shape as well as absent code. Test the pattern on a snippet known to contain the target.
- Inspect node kinds with `--debug-query=ast`, or `--debug-query=pattern` to see how the pattern itself parsed.
- Searches respect `.gitignore` and skip hidden files. Pass `--no-ignore vcs` or `--no-ignore hidden` to include them, and narrow with paths or `--globs '!**/generated/**'`.
- `run` exits 1 when nothing matches, which is not an error.

## Rule files

Use a YAML rule when a pattern alone cannot express the query. Keep scratch rules outside the repository, for example in a `mktemp -d` directory.

```yaml
id: await-in-loop
language: TypeScript
rule:
  pattern: await $CALL
  inside:
    any:
      - kind: for_statement
      - kind: for_in_statement
      - kind: while_statement
      - kind: do_statement
    stopBy:
      any:
        - kind: arrow_function
        - kind: function_declaration
        - kind: function_expression
        - kind: method_definition
```

```bash
ast-grep scan --rule "$rule_dir/await-in-loop.yml" src/
```

- Combine conditions with `all`, `any`, and `not`. Relational keys (`inside`, `has`, `precedes`, `follows`) inspect only the adjacent node by default. `stopBy: end` searches every ancestor, descendant, or sibling in that direction, and a `stopBy` rule stops at the first node it matches, as the example does at function boundaries so that an `await` in a callback defined inside a loop is not reported.
- Match a fragment that does not parse alone, such as an object key, with `pattern: { context: '({ timeout: $V })', selector: pair }`.
- Filter captures with `constraints`, for example `constraints: { NAME: { regex: '^use' } }`.
- `ast-grep scan` without `--rule` or `--inline-rules` needs an `sgconfig.yml` project and fails with exit code 3 otherwise.

## Rewrite

Shell rewrites bypass the hooks attached to the editor tools, including auto-formatting and comment checks, and Claude Code cannot roll them back with its checkpoints. Treat every rewrite as an unreviewed bulk edit.

1. Run `git status --short`. On a clean tree, `git diff` shows only the rewrite and `git restore` undoes it. Uncommitted changes may belong to the user or another agent, so never stash, commit, or restore them. Exclude those files from the rewrite with `--globs '!<path>'`, so that restoring the rewritten files cannot discard them.
2. Preview the change. Adding `-r` to `run`, or a `fix` key to a rule, prints a diff and writes nothing.

   ```bash
   ast-grep run -p 'console.log($$$ARGS)' -r 'logger.info($$$ARGS)' -l ts src/
   ```

3. Read every hunk, then narrow the paths, globs, or pattern until the preview contains only intended changes.
4. Apply the reviewed command unchanged apart from `-U` (`--update-all`). Avoid `-i`, which needs an interactive terminal.
5. Review `git diff` for the rewritten files, then run the project's formatters, linters, and tests on the changed files. ast-grep does not reformat the rewritten code, so the result may not match the project style.

## Scope

Keep each rewrite to one logical change, and split unrelated transformations into separate runs with separate previews. For changes that need type or reference information, such as renaming a symbol with overloads or shadowing, prefer the language server or the language's refactoring tool.
