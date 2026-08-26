# Nix

Read this before adding a module, a package, or a host.

## Module shape

- **NixOS modules** in `modules/nixos/` are typically optionally enabled services. Define `options.hakula.services.<name>.enable`, gate with `config = lib.mkIf cfg.enable { ... }`, and enable from a host or profile.
- **Home Manager modules** in `home/modules/` live under `hakula.<name>`. Branch on `pkgs.stdenv.{isDarwin, isLinux}` for platform variants. The flags `isNixOS` / `isDesktop` are threaded by the host builders, so only consume them when the host actually sets them.
- **Custom packages** in `packages/` are registered through the overlay (`lib/overlays.nix`) and consumed via `pkgs.<name>`. A package needs nothing more than a `default.nix` taking its own inputs, since `callPackage` supplies them.
- **Hosts** in `hosts/` register through one of the five `mk*` builders in `lib/builders.nix`. Reuse profiles from `hosts/_profiles/` for shared hardware or container shapes.

## Function arguments

- **Framework arguments lead, in the order `modulesPath`, `config`, `pkgs`, `lib`, `inputs`.** Whichever of them a file takes keep that relative order and precede everything else, a `packages/` derivation included, where `callPackage` supplies them from nixpkgs.
- **A default that mentions another argument follows it**, so `owner ? "root"` precedes `group ? owner` whatever the alphabet says. Everything else groups by concept under the ordering rule in [Style](#style), which is what keeps `configPath` beside `tokenPath`.

A caller's set lifts its `inherit` entries into a leading block, then follows the order the callee declares. An `inherit` passes through a name the scope already has, so that block reads as context handed down, and lifting it stops an `inherit` from landing between two arguments that belong together. `specialArgs` and `extraSpecialArgs` order the same way. A set that assigns declared options keeps the declaration's order throughout, which is why `enable` stays first.

## Style

- **Formatter**: `nixfmt` (enforced by pre-commit).
- **Linting**: `statix`, `deadnix` (CI). `statix.toml` suppresses W20 `repeated_keys` because the flat-key style is intentional.
- **Line width**: 100 chars (nixfmt default).
- **`with pkgs;`**: use in package lists for brevity.
- **`inherit` placement**: top of `let` blocks, like imports. Combine bindings from the same source: `inherit (pkgs.stdenv) isDarwin isLinux;`. Inside a set that supplies declared options or returns data, keep `inherit` in its logical position (e.g., `group` between `owner` and `path`).
- **Ordering**: group related fields first, then sort within the group when the names are self-describing. Order a `let` block so a binding follows what it depends on. Avoid reshuffling semantic groups just for alphabetical order.

## Section banners

Banners end at column 80, counting the indent. Use equals signs at the file header (no indent), dashes for inner subsections (indented to match surrounding code):

```nix
# ==============================================================================
# Module Name
# ==============================================================================

      # ------------------------------------------------------------------------
      # Subsection
      # ------------------------------------------------------------------------
```

Option-bearing modules use `Module options` and `Module config` banners before the top-level `options` and `config` assignments.

## Comments

Follow the global comment doctrine. The repo-specific addition is that _restyling_ an existing file means matching nearby style rather than blanket-adding or blanket-removing: a file already wearing banners gets one on the new section, a flat module stays flat, and comment density follows suit.
