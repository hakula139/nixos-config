# CI

[The GitHub Actions workflow](../../.github/workflows/ci.yml) runs only on GitHub, so a branch or MR that exists only on GitLab never triggers it.

- **Builds**: check the `Build` job for each affected target. `devvm` builds a full Docker image and finishes last.
- **Fixtures**: a path with a `fixtures` component is exempt from the pre-commit hooks, cspell, and git's line-ending conversion, so script-test fixtures keep exact bytes.
