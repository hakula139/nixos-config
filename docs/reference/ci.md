# CI

[The GitHub Actions workflow](../../.github/workflows/ci.yml) runs only on GitHub, so a branch or MR that exists only on GitLab never triggers it.

- **Coverage**: the flake check also runs the pre-commit hooks and the [script tests](../conventions/nushell.md#testing), but it does not build hosts, so check the `Build` job for each affected target. `devvm` builds a full Docker image and finishes last.
- **macOS**: build `macbook` on a Mac, either locally or through CI's macOS runner.
- **Fixtures**: a path with a `fixtures` component is exempt from the pre-commit hooks, cspell, and git's line-ending conversion, so script-test fixtures keep exact bytes.

See [verification](../../AGENTS.md#verification) for local checks before pushing.
