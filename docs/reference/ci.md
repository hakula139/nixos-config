# CI

[The GitHub Actions workflow](../../.github/workflows/ci.yml) runs on pushes to `main`, pull requests targeting `main`, a daily schedule and manual dispatch. A branch or MR that exists only on GitLab does not trigger it.

`Nix Flake Check` runs `nix flake check --all-systems` to validate the flake and run its configured pre-commit hooks. Once that job passes, `Build` runs a separate job for each of the nine host targets. Verify the relevant host builds as well as the flake check.

Server builds use `colmenaHive.nodes` through `nixosConfigurations`. Each server job compares its derivation with the Colmena deployment derivation and fails if they differ. Deployments can reuse the CI cache when their locked inputs and configuration sources match. Cache uploads to `hakula` are enabled on `main` or when the actor is `hakula139`.

Build `macbook` on macOS, locally or through CI's macOS runner. The `devvm` job builds a complete Docker image and can take longer than the other targets, so check its result before treating CI as complete.

See [verification](../../AGENTS.md#verification) for local checks before pushing.
