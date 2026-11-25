# AGENTS.md: nixos-config

## Read before you edit

| When the task involves                        | Read                  |
| --------------------------------------------- | --------------------- |
| A Nix module, package, or host                | [Nix conventions]     |
| A Nushell script or its tests                 | [Nushell conventions] |
| A secret or a recipient list                  | [Secrets]             |
| Host wiring, builders, or the repository tree | [Architecture]        |
| First-time setup on any platform              | [Bootstrap]           |
| A deployment with nixsw or nixdp              | [Deployment]          |

## Script language

Nushell is the default for new helper scripts. Bash is only for scripts another shell evaluates or sources, as with `makeWrapper --run` snippets, and for `exec` wrappers that only set a variable and hand off.

## Layout

Lines end at column 100, counting the indent, in every language except Python, which follows ruff's 88.

Every language uses these section banners, written with its own comment marker and ending at the line limit. Use equals signs for the unindented file header and dashes for inner subsections, indented to match the surrounding code:

```nix
# ==================================================================================================
# Module Name
# ==================================================================================================

      # --------------------------------------------------------------------------------------------
      # Subsection
      # --------------------------------------------------------------------------------------------
```

Place a file description inside the header banner after the title, and close it with a third line of equals signs.

## Repository safeguards

**Never let an agenix command overwrite a secret with empty or unintended plaintext.** Follow the `agenix` skill.

**`data/corp-domain.nix` can differ from its committed content, and that is expected.** Never delete, restore (`git checkout`, `git restore`), or stage it.

**Never merge a `nixos-config` PR / MR without explicit approval for that PR / MR.** Broad merge approval for other repositories does not cover this repository.

## Verification

`nix develop -c run-hooks` runs the pre-commit hooks, while `nix flake check` evaluates every NixOS host and runs script tests without building hosts or running hooks. Build affected host outputs directly, and build `macbook` on a Mac or through CI's macOS job:

```bash
nix build '.#nixosConfigurations.wsl.config.system.build.toplevel'
nix build '.#systemConfigs.wsl-non-nixos'
nix build '.#packages.x86_64-linux.devvm-docker'
```

Host out paths change on every source edit because `home/modules/nix/default.nix` pins `inputs.self.outPath` into the Nix registry. To show that a refactor preserves behavior, compare the attributes or built files it affects before and after, excluding `registry.json` when diffing `home-manager-files`.

Because the shell hook links the gitignored `.pre-commit-config.yaml` only on shell entry, run `nix develop` once in each worktree, and again after any rebase or merge that changes the hook configuration.

[The GitHub Actions workflow] runs only on GitHub, so a branch or MR that exists only on GitLab never triggers it. Paths with a `fixtures` component are exempt from pre-commit hooks, cspell, and Git line-ending conversion so script-test fixtures keep exact bytes.

## Documentation maintenance

- Keep the repository tree in [Architecture] accurate at its current depth, and add prose below it only for knowledge every module author needs.
- Update the architecture's host table when host wiring changes, and the README and [Deployment] when deployment commands change.

[Nix conventions]: docs/conventions/nix.md
[Nushell conventions]: docs/conventions/nushell.md
[Secrets]: .agents/skills/agenix/SKILL.md
[Architecture]: docs/reference/architecture.md
[Bootstrap]: docs/guides/bootstrap.md
[Deployment]: docs/guides/deployment.md
[The GitHub Actions workflow]: .github/workflows/ci.yml
