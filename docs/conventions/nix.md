# Nix

## Module shape

- **Restart policy**: a long-running NixOS service merges `repoLib.systemd.restartUnit` into its `systemd.services.<name>`, and a Home Manager user service merges `repoLib.systemd.restart` into its `Service` section, instead of setting `Restart=` or start limits itself.
- **Unattended HTTP calls** take curl's common flags from `repoLib.curl.mkArgs`.
- **Unstable packages**: take a package from `pkgs.unstable` only when the stable branch lacks the version you need, and select it at the call site. When something reads `pkgs.<name>` implicitly, as nixpkgs writers and git-hooks.nix hooks do, pin it in the overlay instead, unless stable packages compile against it, as they do against a language toolchain.
- **Module banners**: in option-bearing modules, place `Module options` and `Module config` banners before the top-level `options` and `config` assignments.

## Function arguments

- **Keep parameter lists small.** Access package dependencies through `pkgs` instead of declaring or aliasing each one, and declare only the context and task-specific values the function uses.
- **Accept `...` only when the caller passes a broader argument set**, as the module system does, so `callPackage` targets and other helpers reject unexpected arguments. Keep open record patterns where accepting additional fields is part of the contract.
- **Lay out a file's top-level argument set one argument per line**, even when nixfmt would fit it on one, so adding an argument is a one-line diff.
- **Put framework arguments first, ordered `modulesPath`, `config`, `pkgs`, `lib`, `inputs`**, including in `packages/` derivations.
- **Call argument sets**, `specialArgs` included, follow the leading `inherit` block with the remaining arguments in the callee's declared order.

Diff `nix-instantiate --parse <file>` before and after reordering. Because the parser sorts attributes, formals, and `inherit` names, an empty diff confirms a pure reordering.

## Style

- **Attribute names**: quote a name only when Nix requires it, and then quote every name in that set. Access paths quote only what Nix requires.
- **`inherit` placement**: start `let` blocks and call argument sets with `inherit`, using one statement per source. In sets that assign declared options or return data, keep the declared order and use `inherit` in place.
- **Wrapper arguments**: separate options in Nix lists with a blank line so each reads and diffs as a unit, and set up the environment before fixed command arguments, keeping environment transformations in order.
