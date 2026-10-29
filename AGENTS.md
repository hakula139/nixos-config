# AGENTS.md: nixos-config

Project-specific rules for any coding assistant working in this repository. `CLAUDE.md` is a symlink to this file.

This file is an index. It holds only what applies to every task, while anything needed for one kind of change lives in `docs/`, to be read when you touch that area.

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

Wrap code and comments at 100 columns, counting the indent (Python follows ruff's 88), and keep a single-line string literal whole at any length. nixfmt does not reflow comments. Every language uses the [section banners](docs/conventions/nix.md#section-banners).

## Repository safeguards

**Never let an agenix command overwrite a secret with empty or unintended plaintext.** Follow [docs/guides/secrets.md](docs/guides/secrets.md#editing-and-re-keying).

**`data/corp-domain.nix` can differ from its committed content, and that is expected.** Never delete, restore (`git checkout`, `git restore`), or stage it.

## Verification

`nix flake check` runs the structure checks, pre-commit hooks, and script tests from the dev shell (`nix develop -c zsh`), but builds no host, and its `checks.pre-commit` output alone does not evaluate host modules. For host changes, build each affected output directly, and build `macbook` on a Mac or through CI's macOS job:

```bash
nix build '.#nixosConfigurations.wsl.config.system.build.toplevel'
nix build '.#systemConfigs.wsl-non-nixos'
nix build '.#packages.x86_64-linux.devvm-docker'
```

Host out paths change on every source edit because `home/modules/shared.nix` pins `inputs.self.outPath` into the Nix registry, so to confirm that a refactor preserves behavior, compare what it affects before and after, such as a `nix eval --json` of the changed attribute or a `diff -r --exclude=registry.json` of the built `home-manager-files`. Run `nix develop` once in a worktree under `.claude/worktrees/` to materialize the gitignored pre-commit symlink, and rerun it after a rebase or merge that changes the hook configuration, since the shell hook relinks it only on shell entry.

## Documentation maintenance

Each rule has one home, which other pages link to. Add to `AGENTS.md` or `docs/` only a constraint that is invisible, destructive, or already cost someone a debugging session, and leave out whatever a model can read off `flake.nix`, a representative module, `ls`, or `git log`.

- `README.md` is for a human evaluating or operating the repo: what it manages, how to run it. Keep internal progress out.
- `AGENTS.md` and `docs/` are for whoever is changing the code.
- In [docs/reference/architecture.md](docs/reference/architecture.md), keep the Layout tree accurate at its current depth, and add prose below it only for knowledge every module author needs.
- Check documentation affected by the change, including the architecture's host table when host wiring changes and the README's usage instructions when commands change.
