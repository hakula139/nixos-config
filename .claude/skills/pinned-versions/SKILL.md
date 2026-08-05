---
name: pinned-versions
description: Registry of every manually pinned version in this repo and how to upgrade each one. Use this skill whenever the user wants to audit, check, or bump pinned versions — Claude Code plugin marketplace revs and hashes in plugins.nix, custom package versions under packages/, container image tags on oci-containers services, GitHub Actions `uses:` pins, runtime-installed npm/PyPI versions, or the Cloudflare IP range snapshot. Trigger on phrases like "check for outdated versions", "what's pinned here", "upgrade the claude plugins", "bump cloudreve", "are the actions out of date", "refresh cloudflare IPs", "update pinned hashes", or any request to sweep the repo for stale dependencies. Also use when a `nix build` fails on a hash mismatch after a version bump.
---

# Pinned Versions

Every version in this repo that a human must bump by hand, where it lives, and the procedure to upgrade it.

Renovate handles `flake.lock` on its own. Everything documented here is invisible to it.

## Check for drift

```bash
.claude/skills/pinned-versions/check-pins.sh          # query every upstream, print a drift table
.claude/skills/pinned-versions/check-pins.sh list     # print the registry without network calls
```

Requires `gh` (authenticated) and `jq`, both present in `nix develop`.

Exit codes are distinct so this works unattended:

| Code | Meaning                                               |
| ---- | ----------------------------------------------------- |
| 0    | every pin current                                     |
| 1    | at least one pin is stale                             |
| 2    | an upstream query failed, so the result is incomplete |

Treating 2 as success would report "0 stale" during a network outage, which reads as a clean sweep.

## What Renovate does and does not cover

`.github/renovate.json` sets `"enabledManagers": ["nix"]`, and Renovate's `nix` manager reads only `flake.lock`. Two consequences that surprise people:

- The 13 flake inputs auto-update via grouped `chore(flake)` PRs on a nightly `lockFileMaintenance` schedule, automerged.
- Nothing else is watched. GitHub Actions pins in particular look managed because Renovate exists in the repo, but the `github-actions` manager is off.

`nixpkgs` pins the `nixos-26.05` branch, so package versions inside nixpkgs move with lockfile updates and need no attention here. Only the pins below are manual.

## Registry

### Claude Code plugin marketplaces

`home/modules/llm-assistants/claude-code/plugins.nix`, in the `marketplaces` attrset. Two pinning styles coexist:

| Marketplace               | Upstream                             | Pin style                                |
| ------------------------- | ------------------------------------ | ---------------------------------------- |
| `agent-browser`           | `vercel-labs/agent-browser`          | `rev` + `hash`, comment records the tag  |
| `openai-codex`            | `openai/codex-plugin-cc`             | `rev` + `hash`, comment records the tag  |
| `claude-plugins-official` | `anthropics/claude-plugins-official` | `rev` + `hash`, comment records the date |
| `context7-marketplace`    | `upstash/context7`                   | `rev` + `hash`, comment records the date |
| `anthropic-agent-skills`  | `anthropics/skills`                  | `source = inputs.anthropics-skills`      |
| `workmux`                 | `raine/workmux`                      | `inherit (pkgs.workmux) version`         |

The last two delegate their pin to `flake.lock`, so Renovate keeps them fresh and they need no manual work. The first four do not.

Repos that cut releases (`agent-browser`, `openai-codex`) carry the release tag in the trailing comment. The other two track their default branch, so the comment carries a date instead.

These pins only take effect where `hakula.llm-assistants.claude-code.plugins.bundle` is set, which today is `devvm` alone (`hosts/images/devvm/default.nix`). That flag exists for air-gapped deployment: it prebuilds the plugin cache into the image and sets `CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL`. Everywhere else Claude Code fetches plugins itself at runtime, so a stale `rev` here costs nothing until the image is rebuilt. The `enabledPlugins` list still matters on every host, since it drives which plugins get bundled.

### Custom packages

| Package                 | Location                                         | Upstream                                 |
| ----------------------- | ------------------------------------------------ | ---------------------------------------- |
| `cloudreve`             | `packages/cloudreve/default.nix`                 | `cloudreve/cloudreve` releases           |
| `mcp-server-github`     | `packages/mcp/mcp-server-github/default.nix`     | `github/github-mcp-server` releases      |
| `mcp-server-gitlab`     | `packages/mcp/mcp-server-gitlab/default.nix`     | `zereight/gitlab-mcp` releases           |
| `mcp-server-filesystem` | `packages/mcp/mcp-server-filesystem/default.nix` | `modelcontextprotocol/servers` date tags |
| `mcp-server-git`        | `packages/mcp/mcp-server-git/default.nix`        | `mcp-server-git` on PyPI                 |
| `zsh-hist`              | `packages/zsh-hist/default.nix`                  | `marlonrichert/zsh-hist` default branch  |

`cloudreve` and `mcp-server-github` fetch per-platform release binaries, so each entry in their `sources` attrset carries its own hash and all of them change together.

`mcp-server-filesystem` and `mcp-server-gitlab` are npm builds with a second hash (`npmDepsHash`) that also moves on every version bump.

`peertube` is not pinned here. It tracks `unstable` via the overlay, with three patches applied in `lib/overlays.nix`. The patches are the maintenance burden, since they break when upstream moves.

### Container images

Tags live in the `image` option default of each service module. Podman pulls them at service start.

| Service    | Location                             | Upstream                           |
| ---------- | ------------------------------------ | ---------------------------------- |
| `umami`    | `modules/nixos/umami/default.nix`    | `umami-software/umami` releases    |
| `fuclaude` | `modules/nixos/fuclaude/default.nix` | `pengzhile/fuclaude` on Docker Hub |
| `clove`    | `modules/nixos/clove/default.nix`    | `mirrorange/clove` on Docker Hub   |

Only `umami` is enabled on a host today (`us-4`). The `fuclaude` and `clove` modules are wired into nginx but enabled nowhere, so their tags are dormant and a bump has no deployed effect. Because the tag is a module option, a host can override it without editing the module.

### GitHub Actions

Pinned to major tags across `.github/workflows/` and `.github/actions/setup-nix/action.yml`: `actions/checkout`, `anthropics/claude-code-action`, `cachix/install-nix-action`, `cachix/cachix-action`, `wimpysworld/nothing-but-nix`.

Major-tag pinning means patch and minor updates arrive automatically. Only major bumps need action, and those can carry breaking changes, so read the release notes.

### Runtime-installed packages

Resolved when the service or script runs, so the store path does not change when upstream does.

| Pin       | Location                                        | Upstream                     |
| --------- | ----------------------------------------------- | ---------------------------- |
| `piclist` | `modules/nixos/piclist/server/default.nix`      | `piclist` on npm             |
| `toasty`  | `home/modules/llm-assistants/shared/notify.nix` | `shanselman/toasty` releases |

`piclist` compares its `version` against what is installed in the state directory and reinstalls on mismatch, so bumping the literal is enough to trigger reinstall on next start.

`toasty` is a `fetchurl` of a release asset, so it needs a hash refresh like any custom package. Its upstream also publishes releases with no binaries attached, so the newest tag is not always a bumpable target. `check-pins.sh` reports the newest release that actually ships `toasty-x64.exe`.

Unpinned by design: the `npx -y <package>` MCP wrappers in `home/modules/llm-assistants/shared/mcp/default.nix` and `uvx mcp-atlassian` always resolve latest. `ccusage@latest` in `statusline-command.sh` is the same. These have no pin to bump, which also means they can break without any change on our side.

### Drifting upstream data

`modules/nixos/cloudflare/ips.nix` snapshots Cloudflare's published IP ranges. It carries no version, only a `Last updated` comment, so drift is detected by comparing the ranges themselves.

`modules/nixos/cloudflare/origin-pull-ca.pem` is Cloudflare's origin-pull CA certificate. It expires, and a rotation would need a manual refresh from Cloudflare's docs.

### Versioned nixpkgs attributes

`nodejs_24`, `postgresql_17`, and `python3` are chosen attribute names rather than pinned versions. They move only when someone deliberately renames them, and a `postgresql_17` bump in particular needs a database migration. Listed here so a version sweep does not mistake them for stale pins.

## Upgrade procedures

### Flake inputs

```bash
nix flake update                    # all inputs
nix flake update nixpkgs            # one input
```

Renovate normally does this. Update by hand only when you need an input ahead of the nightly schedule.

### A rev + hash plugin marketplace

1. Find the target revision. For release-tagged repos:

   ```bash
   gh api repos/vercel-labs/agent-browser/releases/latest --jq '.tag_name'
   gh api repos/vercel-labs/agent-browser/commits/<tag> --jq '.sha'
   ```

   For branch-tracking repos, take the default branch HEAD:

   ```bash
   gh api repos/anthropics/claude-plugins-official/commits/main --jq '.sha'
   ```

2. Edit `rev` in the marketplace block and update the trailing comment to the new tag or date.

3. Get the new hash with `nix-prefetch-url`, which is much faster than a full build:

   ```bash
   nix hash convert --hash-algo sha256 --to sri "$(
     nix-prefetch-url --unpack https://github.com/<owner>/<repo>/archive/<rev>.tar.gz
   )"
   ```

   `--unpack` is required, since `fetchFromGitHub` hashes the extracted tree. Sanity-check the invocation by running it against the _current_ rev first and confirming it reproduces the hash already in the file.

4. Validate the hash through the same fetcher the module uses, without waiting on the 4 GiB image:

   ```bash
   nix build --no-link --impure --expr 'let p = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux;
     in p.fetchFromGitHub { owner = "<owner>"; repo = "<repo>"; rev = "<rev>"; hash = "<hash>"; }'
   ```

   Then build `devvm-docker` once at the end to confirm the whole bundle assembles.

5. On every host except `devvm`, Claude Code installs plugins itself at runtime and these pins are inert, so a bump changes nothing until the devvm image is rebuilt.

### A custom package

These are overlay attributes, not flake outputs, so `nix build '.#mcp-server-git'` fails. Build them through the overlay:

```bash
nix build --no-link --print-out-paths --impure --expr \
  'let f = builtins.getFlake (toString ./.);
       p = import f.inputs.nixpkgs {
         system = "x86_64-linux";
         overlays = import ./lib/overlays.nix { inherit (f) inputs; nixpkgs-unstable = f.inputs.nixpkgs-unstable; };
         config.allowUnfree = true;
       };
   in p.<attr>'
```

1. Bump `version`.
2. Replace each hash with a dummy (`sha256-AAAA...` padded to the right length), then build to read the real one from the mismatch error. Per-platform sources report only the building platform's hash, so fetch the others with `nix-prefetch-url` against their release assets.
3. `npmDepsHash` surfaces as a second mismatch only after the source hash is right. It does not always change: a version bump whose lockfile is untouched keeps the same value.
4. Run the built binary. Not every tool has `--version`, so fall back to `--help`. This is what catches a moved entry point in `makeWrapper` or a broken `autoPatchelf`.

### A container image tag

Edit the `image` option default, then redeploy the host:

```bash
colmena apply --on us-4
```

Podman pulls the new tag on service restart. Check the upstream release notes for database migrations first, which matters most for `umami`.

### A GitHub Actions major version

Edit the `uses:` line. CI validates it on the next push, so no local verification is possible.

### Cloudflare IP ranges

```bash
curl -s https://www.cloudflare.com/ips-v4
curl -s https://www.cloudflare.com/ips-v6
```

Replace the `ipv4` and `ipv6` lists, update the `Last updated` comment, then redeploy the servers. Every server enables nginx through `hosts/_profiles/role/server`, so this is a fleet-wide change:

```bash
colmena apply
```

## Verification

Use the build and format commands in the `Verification` section of `CLAUDE.md`. Which target matters depends on the pin class:

| Bumped                            | Build                            |
| --------------------------------- | -------------------------------- |
| Container tag, service version    | the affected server, e.g. `us-4` |
| Custom package, MCP server        | `macbook`, or any workstation    |
| Plugin marketplace `rev` / `hash` | `devvm-docker` only              |

The devvm image is the only target that fetches the plugin marketplace sources, so a wrong `hash` in `plugins.nix` passes every other build. It is also a 4 GiB build, so expect it to be slow on a cold cache.

`macbook` is `aarch64-darwin` and cannot be built from a Linux host: its Homebrew `Brewfile` derivation fails with `platform mismatch`. Verify Darwin-only changes on `macbook` itself, or leave them to CI. For a custom package that builds on both, `wsl` or the overlay invocation above covers the Linux side.
