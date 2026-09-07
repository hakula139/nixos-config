# Git

Follow the global Conventional Commits and PR doctrine, plus the `data/corp-domain.nix` ban in [AGENTS.md](../../AGENTS.md), which bites at commit time. This repo adds these conventions:

- **Scope** is the module name (`mihomo`, `secrets`, `system-manager`), the file (`flake`, `agents`, `readme`), or the host name (`us-2`, `wsl`, `devvm`) for host-scoped changes.
- **PR assignee** is `hakula139`.
- **PR labels** follow the change: `fix` → `bug`, `feat` → `enhancement`, `docs` → `documentation`, and `refactor`, `ci`, or `chore` use the corresponding label. Check recent comparable PRs for other types and exceptions, such as lockfile maintenance using `ci`.
- **PR body** uses `Summary` and `Test plan`, with checked items for completed verification and unchecked items for relevant outstanding checks. Add `Changes` or `Design decisions` only when they help explain the change.
