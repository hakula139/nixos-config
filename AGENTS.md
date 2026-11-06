# AGENTS.md: nixos-config

Project-specific rules for any coding assistant working in this repository. `CLAUDE.md` is a symlink to this file.

## Read before you edit

| When the task involves                        | Read                                                             |
| --------------------------------------------- | ---------------------------------------------------------------- |
| A Nix module, package, or host                | [docs/conventions/nix.md](docs/conventions/nix.md)               |
| A Nushell script or its tests                 | [docs/conventions/nushell.md](docs/conventions/nushell.md)       |
| A secret or a recipient list                  | [.agents/skills/agenix/SKILL.md](.agents/skills/agenix/SKILL.md) |
| Host wiring, builders, or the repository tree | [docs/reference/architecture.md](docs/reference/architecture.md) |
| The workflow or a failing check               | [docs/reference/ci.md](docs/reference/ci.md)                     |
| First-time setup on any platform              | [docs/guides/bootstrap.md](docs/guides/bootstrap.md)             |
| A deployment with nixsw or nixdp              | [README.md](README.md#applying-a-configuration)                  |

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

## Verification

`nix flake check` runs the structure checks, pre-commit hooks, and script tests from the dev shell (`nix develop -c zsh`), but it builds no host and its `checks.pre-commit` output alone does not evaluate host modules. For host changes, build each affected output directly, and build `macbook` on a Mac or through CI's macOS job:

```bash
nix build '.#nixosConfigurations.wsl.config.system.build.toplevel'
nix build '.#systemConfigs.wsl-non-nixos'
nix build '.#packages.x86_64-linux.devvm-docker'
```

Host out paths change on every source edit because `home/modules/shared.nix` pins `inputs.self.outPath` into the Nix registry. To show that a refactor preserves behavior, compare the attributes or built files it affects before and after, excluding `registry.json` when diffing `home-manager-files`.

Because the shell hook links the gitignored `.pre-commit-config.yaml` only on shell entry, run `nix develop` once in a worktree under `.claude/worktrees/`, and again after any rebase or merge that changes the hook configuration.

## Documentation maintenance

- Keep the repository tree in [docs/reference/architecture.md](docs/reference/architecture.md) accurate at its current depth, and add prose below it only for knowledge every module author needs.
- Update the architecture's host table when host wiring changes, and the README's usage instructions when commands change.
