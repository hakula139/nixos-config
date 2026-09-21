# AGENTS.md: nixos-config

Project-specific rules for any coding assistant working in this repository. `CLAUDE.md` is a symlink to this file. Follow the user's global instructions for communication, scope, comment, and commit doctrine.

This file is an index. It holds only what applies to every task, while anything needed for one kind of change lives in `docs/` and should be read when you touch that area. Adding to either place takes a constraint that is invisible, destructive, or already cost someone a debugging session, so leave out whatever a model can read off `flake.nix`, a representative module, `ls`, or `git log`.

## Read before you edit

| Touching                              | Read                                                               |
| ------------------------------------- | ------------------------------------------------------------------ |
| A module, package, or host            | [docs/conventions/nix.md](docs/conventions/nix.md)                 |
| A `.sh` script or inline shell in Nix | [docs/conventions/shell.md](docs/conventions/shell.md)             |
| A `.nu` script                        | [docs/conventions/nushell.md](docs/conventions/nushell.md)         |
| A secret or a recipient list          | [docs/guides/secrets.md](docs/guides/secrets.md)                   |
| First-time setup on any platform      | [docs/guides/bootstrap.md](docs/guides/bootstrap.md)               |
| Host wiring, builders, or the layout  | [docs/reference/architecture.md](docs/reference/architecture.md)   |
| The workflow or a failing check       | [docs/reference/ci.md](docs/reference/ci.md)                       |
| Assistant proxy configuration         | [docs/reference/proxy.md](docs/reference/proxy.md)                 |
| The prose polisher or its model       | [docs/reference/chinese-prose.md](docs/reference/chinese-prose.md) |

## Repository safeguards

**Never run `agenix -r` from an assistant's shell tool.** Re-keying rewrites the encrypted files covered by the recipient rules and is reserved for an interactive terminal. The separate `agenix -e` command reads replacement plaintext from stdin when no TTY is attached, so empty input can erase a secret. Details in [docs/guides/secrets.md](docs/guides/secrets.md).

## Verification

`nix flake check` covers structure and the pre-commit hooks, and `nix develop -c zsh` enters the shell those tools come from. For iteration, build the affected host output directly:

```bash
nix build '.#nixosConfigurations.wsl.config.system.build.toplevel'
nix build '.#systemConfigs.wsl-non-nixos'
nix build '.#packages.x86_64-linux.devvm-docker'
```

For refactors expected to preserve derivation inputs, compare `nix build --no-link --print-out-paths` before and after. The `checks.pre-commit` output alone does not evaluate host modules, so also evaluate or build the affected host outputs. A worktree under `.claude/worktrees/` needs one `nix develop` to materialize the gitignored pre-commit symlink, and `cspell` there checks zero files unless you pass `--no-gitignore`.

## Documentation maintenance

Every page has one home, and the others link to it. Before adding a paragraph, check whether it belongs somewhere that already exists.

- `README.md` is for a human evaluating or operating the repo: what it manages, how to run it. Keep internal progress out.
- `AGENTS.md` and `docs/` are for whoever is changing the code.
- Normally limit edits to [docs/reference/architecture.md](docs/reference/architecture.md) to keeping the Layout tree accurate at its existing level of detail. Update or remove existing paragraphs when they become inaccurate or unnecessary. Add paragraphs below the tree only for essential shared knowledge that every module author needs. Feature behavior and implementation details belong in the PR description unless an existing dedicated document needs updating.
- Check documentation affected by the change, including the architecture's host table when host wiring changes and the README's alias matrix when commands change.
