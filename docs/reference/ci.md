# CI

`.github/workflows/ci.yml` runs on GitHub pushes to `main`, pull requests targeting `main`, a daily schedule and manual dispatch. A GitLab-only branch or MR does not trigger this workflow.

1. **Nix Flake Check** runs `nix flake check --all-systems`, which validates flake structure and runs every pre-commit hook.
2. **Build** fans out over a matrix of all 9 host targets, one job each. Successful builds upload to the `hakula` Cachix cache on `main` or when the actor is `hakula139`. Server `nixosConfigurations` are the evaluated `colmenaHive.nodes`, so CI and Colmena share the same deployment outputs. Cache reuse requires the same locked inputs and configuration sources.

Two things the job list does not tell you:

- **`macbook` cannot be built on Linux.** The Brewfile derivation fails a platform check. Build Darwin changes on macOS, locally or through CI.
- **`devvm` is the long pole.** The Docker image takes roughly half an hour, well past the other targets, so a green flake check with `devvm` still pending is normal rather than a stall.

For what to run before pushing, see [verification](../../AGENTS.md#verification).
