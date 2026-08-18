# Git

Follow the global Conventional Commits and PR doctrine. This repo adds two rules.

- **Scope** is the module name (`mihomo`, `secrets`, `system-manager`), the file (`flake`, `agents`, `readme`), or the host name (`us-2`, `wsl`, `devvm`) for host-scoped changes.
- **Never commit `data/corp-domain.nix` with the real value.** The placeholder lives in git while the real value stays working-tree only. Audit it before pushing a long branch.
