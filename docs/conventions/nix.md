# Nix

## Module shape

- **Restart policy**: a long-running NixOS service merges `repoLib.systemd.restartUnit` into its `systemd.services.<name>`, and a Home Manager user service merges `repoLib.systemd.restart` into its `Service` section, instead of setting `Restart=` or start limits itself.
- **Unattended HTTP calls** take curl's common flags from `repoLib.curl.mkArgs`, with both timeouts set for the endpoint.
- **Unstable packages**: take a package from `pkgs.unstable` only when the stable branch lacks the version you need, and select it at the call site. When something reads `pkgs.<name>` implicitly, as a module's package default does, pin it in the overlay instead, unless stable packages compile against it, as they do against a language toolchain.

## Function arguments

- **Keep parameter lists small.** Access package dependencies through `pkgs` instead of declaring or aliasing each one, and declare only the context and task-specific values the function uses.
- **Accept `...` only when the caller passes a broader argument set**, as the module system does, so `callPackage` targets and other helpers reject unexpected arguments. Keep open record patterns where accepting additional fields is part of the contract.
- **Lay out a file's top-level argument set one argument per line**, even when nixfmt would fit it on one, so adding an argument is a one-line diff.
- **Put framework arguments first, ordered `modulesPath`, `config`, `pkgs`, `lib`, `inputs`**, including in `packages/` derivations. In a call's argument set, including `specialArgs`, follow the leading `inherit` block with the remaining arguments in the callee's declared order.

Diff `nix-instantiate --parse <file>` before and after reordering. Because the parser sorts attributes, formals, and `inherit` names, an empty diff confirms a pure reordering.

## Style

- **Embedded text**: keep substantial scripts and prose in adjacent files loaded with `builtins.readFile` so their own formatters and linters can check them. Name model-facing prose `prompt.md`, or `<role>-prompt.md` when there are several, so the Markdown checks find it.
- **Attribute names**: quote a name only when Nix requires it, and then quote every name in that set for uniformity.
- **`inherit` placement**: start `let` blocks and call argument sets with `inherit`, using one statement per source. In sets that assign declared options or return data, keep the declared order and use `inherit` in place.
- **Format generators**: bind `json = pkgs.formats.json { };` once in the `let` block that uses it and call `json.generate`, doing the same for YAML and TOML.
- **Wrapper arguments**: keep each wrapper option with its operands, and separate options in Nix lists with a blank line so each reads and diffs as a unit. Set up the environment before passing fixed command arguments, preserving the order of environment transformations and the callee's order for fixed arguments.

## Section banners

Banners end at column 100, including indentation. Use equals signs for the file header (unindented) and dashes for inner subsections (indented to match the surrounding code):

```nix
# ==================================================================================================
# Module Name
# ==================================================================================================

      # --------------------------------------------------------------------------------------------
      # Subsection
      # --------------------------------------------------------------------------------------------
```

In any language that uses these banners, place a file description inside the header banner after the title and close it with a third line of equals signs.

In option-bearing modules, place `Module options` and `Module config` banners before the top-level `options` and `config` assignments.
