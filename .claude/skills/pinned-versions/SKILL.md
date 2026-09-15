---
name: pinned-versions
description: >-
  Registry of every manually pinned version in this repo and how to upgrade each one. Use this skill whenever the user wants to audit, check, or bump pinned versions: Claude Code plugin marketplace revs and hashes in plugins.nix, custom package versions under packages/, release tags in flake input URLs, container image tags on oci-containers services, GitHub Actions `uses:` pins, runtime-installed package versions, or the Cloudflare IP range snapshot. Trigger on phrases like "check for outdated versions", "what's pinned here", "upgrade the claude plugins", "bump cloudreve", "are the actions out of date", "refresh cloudflare IPs", "update pinned hashes", or any request to sweep the repo for stale dependencies. Also use when a `nix build` fails on a hash mismatch after a version bump.
---

# Pinned Versions

Every version in this repo that a human must bump by hand, where it lives, and the procedure to upgrade it.

Renovate maintains `flake.lock`. The registry below covers versions and refs that still require manual changes.

## Check for drift

```bash
.claude/skills/pinned-versions/check-pins.nu          # query every upstream, print a drift table
.claude/skills/pinned-versions/check-pins.nu list     # print the registry without network calls
```

Requires an authenticated `gh`, present in `nix develop`.

Exit codes are distinct so this works unattended:

| Code | Meaning                                                              |
| ---- | -------------------------------------------------------------------- |
| 0    | every pin current                                                    |
| 1    | at least one pin is stale                                            |
| 2    | the run was incomplete: a query failed or a prerequisite was missing |

Treating 2 as success would report "0 stale" during a network outage, which reads as a clean sweep. A pin group that extracts nothing reports UNKNOWN for the same reason.

## What Renovate does and does not cover

`.github/renovate.json` enables only Renovate's `nix` manager. It discovers `flake.nix` and updates resolved inputs in `flake.lock`:

- Resolved flake inputs refresh through grouped `chore(flake)` PRs on a nightly `lockFileMaintenance` schedule, automerged. An explicit release tag in an input URL stays on that tag until the URL changes.
- Nothing else is watched. GitHub Actions pins in particular look managed because Renovate exists in the repo, but the `github-actions` manager is off.

`nixpkgs` follows `nixos-26.05`, so its packages move with lockfile updates within that release branch. Moving to a new NixOS release requires updating the related input refs in `flake.nix`.

`ccusage` and the assistant CLIs come from the locked `llm-agents` input through `lib/overlays.nix`. Home Manager installs that ccusage package, and Claude Code invokes it directly from its status line. Use `nix flake update llm-agents` to advance those packages together.

## Registry

### Versioned flake input refs

`listenbrainz-scrobbler` selects a release tag in its `flake.nix` URL. Check `hakula139/listenbrainz-scrobbler` releases, update that tag, then run `nix flake update listenbrainz-scrobbler`. Lockfile maintenance alone keeps resolving the selected tag.

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

These pins take effect when `hakula.claude-code.plugins.bundle` is enabled, currently in `devvm` (`hosts/images/devvm/default.nix`). Bundling prebuilds the enabled plugin cache and sets `CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL`. Other hosts let Claude Code fetch marketplaces at runtime. The `enabledPlugins` attrset controls plugin enablement on every host and selects marketplace sources for the bundle.

Bundling defaults `plugins.online` to false, so `devvm` excludes `agent-browser` and `context7-marketplace`. Its build does not validate those two source hashes. Fetch each changed marketplace source explicitly before checking the assembled bundle.

### Nix-built packages and helpers

| Package                 | Location                                                | Upstream                                 |
| ----------------------- | ------------------------------------------------------- | ---------------------------------------- |
| `acpx`                  | `packages/acpx/default.nix`                             | `openclaw/acpx` releases                 |
| `cloudreve`             | `packages/cloudreve/default.nix`                        | `cloudreve/cloudreve` releases           |
| `mcp-server-github`     | `packages/mcp/mcp-server-github/default.nix`            | `github/github-mcp-server` releases      |
| `mcp-server-gitlab`     | `packages/mcp/mcp-server-gitlab/default.nix`            | `zereight/gitlab-mcp` releases           |
| `mcp-server-filesystem` | `packages/mcp/mcp-server-filesystem/default.nix`        | `modelcontextprotocol/servers` date tags |
| `mcp-server-git`        | `packages/mcp/mcp-server-git/default.nix`               | `mcp-server-git` on PyPI                 |
| `zsh-hist`              | `packages/zsh-hist/default.nix`                         | `marlonrichert/zsh-hist` default branch  |
| `toasty`                | `home/modules/llm-assistants/shared/notify/default.nix` | `shanselman/toasty` releases             |

`cloudreve` and `mcp-server-github` fetch per-platform release binaries, so each entry in their `sources` attrset carries its own hash and all of them change together.

`mcp-server-filesystem` and `mcp-server-gitlab` are npm builds with a second hash (`npmDepsHash`) that tracks the lockfile.

`acpx` uses `fetchPnpmDeps`, so its source hash and `pnpmDeps.hash` must both match the selected release.

`toasty` is fetched into the Nix store with `fetchurl`. Its releases can omit binaries, so `check-pins.nu` compares against the newest release that includes `toasty-x64.exe`.

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

`piclist` is pinned in `modules/nixos/piclist/server/default.nix` and installed from npm at service start. The service compares `version` against the installed package in its state directory and reinstalls on mismatch, so bumping the literal triggers reinstall on the next start.

The npm and uv MCP wrappers in `home/modules/llm-assistants/shared/mcp/default.nix` leave package versions unspecified, including `mcp-atlassian` and `scrapling[ai]`. Their resolution and caches are managed by `npx` / `uvx`, so updates can arrive without a Nix configuration change. They have no version pin for this checker to compare.

### Drifting upstream data

`modules/nixos/cloudflare/ips.nix` snapshots Cloudflare's published IP ranges. It carries no version, only a `Last updated` comment, so drift is detected by comparing the ranges themselves.

### Versioned nixpkgs attributes

`nodejs_24` and `postgresql_17` select major versions whose patch releases follow nixpkgs. Changing those majors requires choosing another attribute, and PostgreSQL needs a database migration. `python3` follows nixpkgs' default Python 3 version, so its minor version can change without renaming the attribute.

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

4. Validate each changed hash through the same fetcher the module uses:

   ```bash
   nix build --no-link --impure --expr 'let p = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux;
     in p.fetchFromGitHub { owner = "<owner>"; repo = "<repo>"; rev = "<rev>"; hash = "<hash>"; }'
   ```

   Then build `devvm-docker` once at the end to confirm its enabled plugin bundle assembles. This excludes online-only marketplaces under the current settings.

### A custom package

These are overlay attributes rather than flake outputs, so `nix build '.#mcp-server-git'` fails. Build them through the overlay:

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
3. Dependency hashes (`npmDepsHash` or `pnpmDeps.hash`) surface as a second mismatch after the source hash is right. Rebuild to verify them even when the dependency lockfile is unchanged.
4. Run the built binary. Not every tool has `--version`, so fall back to `--help`. This is what catches a moved entry point in `makeWrapper` or a broken `autoPatchelf`.

### A container image tag

Edit the `image` option default, then redeploy the host:

```bash
colmena apply --on us-4
```

Podman pulls the new tag on service restart. Check the upstream release notes for database migrations first, which matters most for `umami`.

### A GitHub Actions major version

Edit the `uses:` line and check the workflow syntax locally. GitHub Actions must execute the workflow to validate the action's runtime behavior. See [CI](../../../docs/reference/ci.md) for triggers.

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

Use the build and format commands in the `Verification` section of `AGENTS.md`. Which target matters depends on the pin class:

| Bumped                            | Build                                    |
| --------------------------------- | ---------------------------------------- |
| Container tag, service version    | the affected server, e.g. `us-4`         |
| Custom package, MCP server        | the overlay invocation above, or `wsl`   |
| Plugin marketplace `rev` / `hash` | direct source fetch, then `devvm-docker` |

The devvm image is the only bundled target, and it fetches only sources referenced by its enabled plugins. Direct fetcher builds are required to validate hashes outside that set. The full image build can be slow on a cold cache.
