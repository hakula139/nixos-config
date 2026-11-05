---
name: nix
description: >-
  Write and review Nix code. Use when a task touches a `.nix` file.
---

# Nix

## Function arguments

- **Declare only the arguments the function uses, and accept `...` only when the caller passes a broader argument set**, as the module system does, so `callPackage` targets and other helpers reject unexpected arguments. Keep open record patterns where accepting additional fields is part of the contract.
- **Lay out a file's top-level argument set one argument per line**, even when the formatter would fit it on one, so adding an argument is a one-line diff.
- **In call argument sets**, `specialArgs` included, pass the arguments in the callee's declared order.

Diff `nix-instantiate --parse <file>` before and after reordering. Because the parser sorts attributes, formals, and `inherit` names, an empty diff confirms a pure reordering.

## Style

- **Attribute names**: quote a name only when Nix requires it, in sets and access paths alike.
- **Option lists**: separate options in Nix lists with a blank line so each reads and diffs as a unit, and keep environment transformations in their order.
