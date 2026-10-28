# Nix

## Module shape

- **Restart policy**: a long-running NixOS service merges `repoLib.systemd.restartUnit` into its `systemd.services.<name>`, and a Home Manager user service merges `repoLib.systemd.restart` into its `Service` section, instead of setting `Restart=` or start limits itself.
- **Host flags**: NixOS modules receive `isDesktop` only, while Home Manager modules receive both `isDesktop` and `isNixOS`.
- **Unattended HTTP calls** from a service, timer, launchd agent, activation script, or hook take curl's common flags from `repoLib.curl.mkArgs`, with both timeouts chosen for the endpoint.

## Function arguments

- **Keep parameter lists small.** Access package dependencies through `pkgs`, such as `pkgs.nodejs_26`, instead of declaring each dependency as a parameter or adding aliases just to shorten its name. Declare only the context and task-specific values the function uses.
- **Use `...` when the caller supplies a broader argument set.** NixOS and Home Manager module functions need it for framework arguments. Packages called through `callPackage` and ordinary helpers with explicitly constructed argument sets omit it, so unexpected arguments are caught. Keep open record patterns where accepting additional fields is part of the contract.
- **Top-level attribute-set argument lists are multiline.** Put each argument and the `...` entry on its own line, even when the list fits on one line.
- **Framework arguments lead, in the order `modulesPath`, `config`, `pkgs`, `lib`, `inputs`.** Whichever of them a file takes keep that relative order and precede everything else, a `packages/` derivation included, where `callPackage` supplies them from nixpkgs.
- **A default that mentions another argument follows it**, so `owner ? "root"` precedes `group ? owner` whatever the alphabet says.

A call's argument set, `specialArgs` and `extraSpecialArgs` included, follows the callee's declared order after a leading `inherit` block.

Diff `nix-instantiate --parse <file>` before and after a reordering. The parser sorts attributes, formals, and `inherit` names, so an empty diff proves a pure reordering.

## Style

- **Embedded text**: keep substantial scripts and prose in adjacent files loaded with `builtins.readFile`, inlining only short wrappers or generated snippets. Name model-facing prose `prompt.md`, or `<role>-prompt.md` when there are several, so Markdown and prose checks see it.
- **Attribute names**: quote one only when Nix requires it, and quote every name in a set where any needs quotes. Access paths follow the first rule.
- **`with pkgs;`**: use in package lists for brevity.
- **`inherit` placement**: lead `let` blocks and call argument sets, combining names from one source (`inherit (pkgs.stdenv) isDarwin isLinux;`). A set that assigns declared options or returns data keeps the declaration's order, with `inherit` in place (`group` between `owner` and `path`).
- **Format generators**: bind `json = pkgs.formats.json { };` (likewise `yaml` and `toml`) once in the `let` block that uses it, after the `inherit` bindings and `cfg`, then call `json.generate`. Avoid inline `(pkgs.formats.json { }).generate`.
- **Wrapper arguments**: keep each wrapper option and its operands together, separating options in Nix lists with a blank line. Put environment setup before fixed command arguments. Preserve the order of environment transformations and pass fixed arguments in the callee's order.

## Section banners

Banners end at column 100, counting the indent. Use equals signs at the file header (no indent), dashes for inner subsections (indented to match surrounding code):

```nix
# ==================================================================================================
# Module Name
# ==================================================================================================

      # --------------------------------------------------------------------------------------------
      # Subsection
      # --------------------------------------------------------------------------------------------
```

A file description, in any language using these banners, goes inside the header banner after the title and is closed by a third rule of equals signs.

Option-bearing modules use `Module options` and `Module config` banners before the top-level `options` and `config` assignments.
