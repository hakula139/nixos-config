# Nix

General Nix conventions live in the `nix` skill. This page covers the choices and wiring specific to nixos-config.

## Module shape

- **Restart policy**: a long-running NixOS service merges `repoLib.systemd.restartUnit` into its `systemd.services.<name>`, and a Home Manager user service merges `repoLib.systemd.restart` into its `Service` section, instead of setting `Restart=` or start limits itself.
- **Unattended HTTP calls** pass curl's `-fsSL` and explicit connect and max timeouts in their own argument list.
- **Unstable packages**: take a package from `pkgs.unstable` only when the stable branch lacks the version you need, and select it at the call site. When something reads `pkgs.<name>` implicitly, as nixpkgs writers and git-hooks.nix hooks do, pin it in the overlay instead, unless stable packages compile against it, as they do against a language toolchain.
- **Module banners**: in option-bearing modules, place `Module options` and `Module config` banners before the top-level `options` and `config` assignments.

## Function arguments

- **Reach package dependencies through `pkgs`**, `callPackage` targets included, instead of declaring or aliasing each one. Once a function uses two or more attributes of a set, take the set and read `A.x` at each use, and give similar files the same parameter even when one of them uses a single attribute.
- **Put framework arguments first, ordered `modulesPath`, `config`, `pkgs`, `lib`, `inputs`**, including in `packages/` derivations, then shared records such as `repoLib` or `shared`, then the task-specific values. Similar files list the same parameters in the same order.

## Style

- **Attribute names**: once one name in a set requires quotes, quote every name in that set.
- **`inherit` placement**: start `let` blocks and call argument sets with `inherit`, using one statement per source. In sets that assign declared options or return data, keep the declared order and use `inherit` in place.
- **Wrapper environment**: set up the environment before fixed command arguments.
