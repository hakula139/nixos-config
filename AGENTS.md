# AGENTS.md: nixos-config

Project-specific rules for any coding assistant working in this repository. `CLAUDE.md` is a symlink to this file.

## Read before you edit

| Touching                              | Read                                                                     |
| ------------------------------------- | ------------------------------------------------------------------------ |
| A module, package, or host            | [docs/conventions/nix.md](docs/conventions/nix.md)                       |
| A `.nu` script or a `.test.nu` file   | [docs/conventions/nushell.md](docs/conventions/nushell.md)               |
| A `.sh` script or inline shell in Nix | [docs/conventions/shell.md](docs/conventions/shell.md)                   |
| First-time setup on any platform      | [docs/guides/bootstrap.md](docs/guides/bootstrap.md)                     |
| A secret or a recipient list          | [docs/guides/secrets.md](docs/guides/secrets.md)                         |
| Host wiring, builders, or the layout  | [docs/reference/architecture.md](docs/reference/architecture.md)         |
| The workflow or a failing check       | [docs/reference/ci.md](docs/reference/ci.md)                             |
| The prose polish skill or its model   | [docs/reference/prose-evaluation.md](docs/reference/prose-evaluation.md) |
| A deployment with nixsw or nixdp      | [README.md](README.md#applying-a-configuration)                          |

## Layout

Wrap code and comments at 100 columns including the indent (Python follows ruff's 88), and keep a single-line string literal, and a table row holding one, whole at any length. nixfmt does not reflow comments. Every language uses the [section banners](docs/conventions/nix.md#section-banners).

Where the formatter leaves line breaks to the author, lay code out for the reader and for diffs. An external call or argument list with two or more options, bare flags included, keeps its command, subcommands, and positionals on the first line and puts each option with its value on its own line one level deeper, in any order its parser requires, and a wrapped command starts a deeper line. Split a pipeline that transforms data step by step into one stage per line, and write a construct with more than one branch across lines, except a short `if` / `else` between plain values, which reads as a ternary.

## Repository safeguards

**Never let an agenix command overwrite a secret with empty or unintended plaintext.** Follow [docs/guides/secrets.md](docs/guides/secrets.md#editing-and-re-keying).

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

Each rule has one home that other pages link to. Add a constraint to `AGENTS.md` or `docs/` only if it is invisible, is destructive, or has already cost someone a debugging session, and leave out anything a model can infer from the code, tool behavior, or `git log`.

- `README.md` is for a human evaluating or operating the repo, so keep internal progress out of it.
- `AGENTS.md` and `docs/` are for whoever is changing the code, with `AGENTS.md` limited to what applies to every task.
- Keep the Layout tree in [docs/reference/architecture.md](docs/reference/architecture.md) accurate at its current depth, and add prose below it only for knowledge every module author needs.
- Update the architecture's host table when host wiring changes, and the README's usage instructions when commands change.
