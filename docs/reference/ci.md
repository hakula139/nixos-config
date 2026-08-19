# CI

`.github/workflows/ci.yml` runs on every push and pull request:

1. **Nix Flake Check** runs `nix flake check --all-systems`, which validates flake structure and runs every pre-commit hook.
2. **Build** fans out over a matrix of all 9 host targets, one job each. Successful builds upload to the `hakula` Cachix cache on `main` or when the actor is `hakula139`.

Two things the job list does not tell you:

- **`macbook` cannot be built on Linux.** The Brewfile derivation fails a platform check, so CI is the only verification path for a Darwin change.
- **`devvm` is the long pole.** The Docker image takes roughly half an hour, well past the other targets, so a green flake check with `devvm` still pending is normal rather than a stall.

For what to run before pushing, see [verification](../../AGENTS.md#verification).
