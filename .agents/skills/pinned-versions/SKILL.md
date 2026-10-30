---
name: pinned-versions
description: >-
  Audit or upgrade manually pinned dependencies in nixos-config, including plugin revisions, custom
  packages, flake release tags, container images, runtime packages, and Cloudflare IP ranges, and
  review Renovate's GitHub Actions updates. Use for stale dependency sweeps or hash
  mismatches after version bumps.
---

# Pinned Versions

Locate pins through `scripts/check-pins.nu`, compare upstream versions, and update the relevant source and hashes. Run commands from the repository root. An audit only reports drift, while the update steps apply to a request that asks for upgrades. When upgrading, keep unrelated pins and lockfile inputs outside the change, and deploy only when the requested scope includes activation. Skip a pin that another open request owns, and name that request in the upgrade request's description.

Before bumping a pin, check whether upstream has made local overrides or patches unnecessary. Remove patches whose fixes are included upstream. Keep any remaining behavior overrides and update the checker registry and affected instructions to match.

## Check for drift

```bash
.agents/skills/pinned-versions/scripts/check-pins.nu
```

`list` prints the registry without network calls and needs Nushell and Git. Comparison also needs Nix for the override rows, plus `gh` authenticated to `github.com`, which `nix develop` does not supply. `UNKNOWN` means a lookup failed, usually from a transient fetch failure, so rerun before acting on it. `STALE` means the registered value differs from upstream, so inspect the upstream target before deciding to upgrade. On an override row, `version pin superseded` means `nixpkgs-unstable` ships the latest upstream release at or above the pinned version. `override redundant` means the row has no version pin, and its derivation and platforms match `nixpkgs-unstable`. `ok (tracks nixpkgs)` means the override differs from `nixpkgs-unstable` in more than its version, through patches, build overrides, or platforms. The checker compares registered values only, so it does not validate hashes, compatibility, or deployed versions.

To update an override of a nixpkgs package, find its latest upstream release first. If `nixpkgs-unstable` already ships that release at or above the pin, drop the `version`, its `src` hash override, and any dependency hashes that exist only for the bump, keeping patches, build overrides, and meta. Otherwise bump the override to that release. Delete the package only when nothing else remains, and deleting it also means removing its overlay line, pointing its consumers at `pkgs.unstable.<name>`, and dropping its Cachix pin in `.github/workflows/ci.yml`. After a bump or a partial deletion, build the package, since remaining patches and platform additions must still apply to the new upstream version.

The registry can lag the repository. For a repository-wide audit, also inspect new packages, flake inputs, service defaults, and workflow references.

## Locked inputs and release selectors

Renovate manages `flake.lock` inputs and GitHub Actions, so a manual sweep leaves those alone, including rolling inputs such as `llm-agents`. Update a selected input with `nix flake update <input>` only when its selector changes in `flake.nix`. An input pinned to a release tag selects nothing newer than that tag, so change the tag first. The inputs that select NixOS release branches need review together for a release upgrade, and the checker does not compare them.

### Nixpkgs package selections

Package attributes that select a major, such as `postgresql_17`, follow the lockfile for patch versions, and they need review separately from the checker's comparisons. Changing PostgreSQL's major requires a database migration.

A NixOS release upgrade rechecks each `pkgs.unstable` pick and overlay pin against the [unstable packages rule](../../../docs/conventions/nix.md#module-shape).

`peertube` follows the `nixpkgs-unstable` version, with three local patches and an `aarch64-darwin` platforms addition on the package itself. `peertube-runner` is a build override in `packages/peertube/runner.nix` that derives from it, and a version move can break it. A sweep pins a version again only when upstream is ahead of `nixpkgs-unstable`. Review release-specific migration requirements before changing the version, run required manual migrations during deployment and verify their results, and keep one-time migration services out of the persistent configuration.

## Claude Code plugin marketplaces

The manual marketplace revisions control the prebuilt Claude Code cache only when `hakula.claude-code.plugins.bundle` is enabled, currently in `devvm`. Unbundled Claude Code fetches its marketplaces at runtime, so these hashes do not pin that cache.

To update a manual marketplace:

1. Resolve the default branch to a commit. Update `rev` and its date comment together, since the checker reads the revision from code.

2. Obtain the extracted-tree hash. `fetchFromGitHub` requires `--unpack` when prefetching an archive:

   ```bash
   nix store prefetch-file --json --unpack \
     'https://github.com/<owner>/<repo>/archive/<rev>.tar.gz'
   ```

   The output carries the SRI hash. Check this invocation against the existing revision and hash when using a different archive URL or fetch method.

3. Validate each changed source with the module's fetcher, substituting the marketplace values:

   ```bash
   nix build --no-link --impure --expr '
     let
       p = (builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.x86_64-linux;
     in
     p.fetchFromGitHub {
       owner = "<owner>";
       repo = "<repo>";
       rev = "<rev>";
       hash = "<hash>";
     }
   '
   ```

4. Build `.#packages.x86_64-linux.devvm-docker` to check the assembled cache.

## Nix-built packages and fetched helpers

### Overlay packages

Update the package's `version` and source hash, staying on the release channel the pin already uses (alpha, beta, or rc) unless a stable release at or above it exists. Commit-pinned packages such as `zsh-hist` need `src.rev`, `src.hash`, and the date in their `0-unstable-YYYY-MM-DD` version changed together.

Dependencies beyond the source need these hashes:

- `acpx` needs `pnpmDeps.hash`, and `wakatime-cli` needs `vendorHash`.
- `mcp-server-gitlab` needs `npmDepsHash`. Rebuild to validate dependency hashes even when the upstream lockfile appears unchanged.
- `cloudreve` and `mcp-server-github` fetch release archives with `fetchurl`. Prefetch their bytes without `--unpack`, and update every platform entry, including those unavailable locally.
- `netdata` needs the GitHub source hash. Its Go module and cargo vendor hashes come from the `nixpkgs-unstable` expression and are named after `version`, so a bump that changes them fails with an FOD mismatch and they must then be overridden in `packages/netdata/default.nix`.

Use `lib.fakeHash` temporarily to obtain a hash from a Nix mismatch error, resolving dependency hashes after the source hash. `fetchPnpmDeps` recomputes the whole dependency tree, which takes a full build here, and the mismatched fixed-output derivation is discarded, so the package build repeats the fetch. Never leave a placeholder hash in the final change.

The custom packages are overlay attributes rather than flake outputs, so build them through the overlay:

```bash
nix build --no-link --print-out-paths --impure --expr '
  let
    f = builtins.getFlake (toString ./.);
    p = import f.inputs.nixpkgs {
      system = "x86_64-linux";
      overlays = import ./lib/overlays.nix { inherit (f) inputs; };
      config.allowUnfree = true;
    };
  in
  p.acpx
'
```

For executable packages, run a supported `--version` or `--help` from the store path to catch wrapper, entry-point, or loader failures. `zsh-hist` has no executable, so verify its loading and `hist` command in an isolated Zsh session without modifying the user's history.

### Windows notification helper

`toasty` is a local binding, so the overlay build above does not produce it. Update its release tag and `fetchurl` hash together, then build a Linux host that enables assistant notifications, such as `wsl`, to validate the fetch and wrapper. Runtime notification verification requires Windows interoperability in WSL.

## Container images and runtime packages

### Container images

Review release notes for application and database migrations, then edit the tag and build the affected host. Nix builds validate the service configuration but do not fetch the container image or test its runtime. Umami runs on `us-4`. Inspect host overrides before changing a default, since the checker does not evaluate effective host image options. `colmena apply --on us-4` deploys an Umami update, and Podman resolves the configured image when starting the container.

### Unpinned MCP wrappers

The `npx` and `uvx` MCP wrappers float on each package's latest release, so they stay outside the checker.

## GitHub Actions

Renovate owns these refs. Review its PRs for breaking changes, and run local workflow checks. Upstream can move an existing major tag without a PR, so verify an actual GitHub Actions run for runtime behavior. GitHub CI runs only on GitHub, so a GitLab-only MR triggers none. See [CI](../../../docs/reference/ci.md) for triggers.

## Cloudflare IP ranges

The Cloudflare range snapshot feeds nginx's real IP configuration, and the checker compares the range sets while treating the `Last updated` comment as the displayed local value. Fetch both lists, then update both and the date once both requests succeeded:

```bash
curl -fsS https://www.cloudflare.com/ips-v4
curl -fsS https://www.cloudflare.com/ips-v6
```

Every server enables nginx through `hosts/_profiles/role/server`, so the change spans the server fleet. Validate server builds, and when a fleet deployment is requested, `colmena apply` applies it.

## Verification

Follow [repository verification](../../../AGENTS.md#verification) for formatting and builds. Select checks by the changed source: direct package or marketplace fetches first, then the affected host or plugin bundle. A source fetch for another platform verifies its hash but does not prove its binary runs there.

Report which pins changed, the upstream releases or commits selected, and the checks actually completed. Keep incomplete upstream queries and untested runtime or deployment behavior explicit.
