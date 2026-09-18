---
name: pinned-versions
description: >-
  Audit or upgrade manually pinned dependencies in nixos-config, including plugin revisions, custom packages, flake release tags, container images, GitHub Actions, runtime packages, and Cloudflare IP ranges. Use for stale dependency sweeps or hash mismatches after version bumps.
---

# Pinned Versions

Locate pins, compare upstream versions, and update the relevant source and hashes. Run commands from the repository root. A version audit requires no changes. When upgrading, keep unrelated pins and lockfile inputs outside the change, and deploy only when the requested scope includes activation.

## Check for drift

```bash
.agents/skills/pinned-versions/scripts/check-pins.nu list     # list the registry without network calls
.agents/skills/pinned-versions/scripts/check-pins.nu          # compare registered pins with upstream
```

Listing the registry requires Nushell and Git. Upstream comparisons also require GitHub CLI (`gh`) authenticated to `github.com`. `nix develop` supplies Nushell but does not install `gh`. Its registry covers the pins below. For a repository-wide audit, also inspect new packages, inputs, service defaults, and workflow references that may not have been added to the checker.

| Exit code | Meaning                                                     |
| --------- | ----------------------------------------------------------- |
| 0         | No drift detected among the compared pins                   |
| 1         | At least one registered pin differs from its upstream value |
| 2         | A prerequisite, extraction, or upstream query failed        |

`UNKNOWN` leaves the comparison incomplete, including when a pin group extracts nothing. `STALE` means the compared values differ, so inspect the upstream target before deciding to upgrade. The checker does not validate hashes, compatibility, or deployed versions. Entries marked `renovate` delegate their source to `flake.lock` and are not queried individually.

## Locked inputs and release selectors

`.github/renovate.json` enables only the `nix` manager, with grouped `chore(flake)` PRs and automerge. It configures daily lockfile maintenance in Asia/Shanghai time. GitHub Actions and the manual pins below are outside that manager.

Update a selected input with `nix flake update <input>`. An explicit tag or release branch in `flake.nix` constrains what a lockfile refresh can select:

- `listenbrainz-scrobbler` uses a release tag. Choose a release from `hakula139/listenbrainz-scrobbler`, update its URL, then run `nix flake update listenbrainz-scrobbler`.
- `nixpkgs`, `nixos-wsl`, `nix-darwin`, `home-manager`, and `system-manager` select the 26.05 release branches. Review these selectors together for a NixOS release upgrade. The checker compares only the scrobbler tag.
- Assistant CLIs, ACP adapters, `ccusage`, and `workmux` come from `llm-agents` through `lib/overlays.nix`. Use `nix flake update llm-agents` to refresh that source.
- `anthropics-skills` and `openai-skills` are non-flake inputs whose revisions also live in `flake.lock`.

### Nixpkgs package selections

Package attributes such as `nodejs_24` and `postgresql_17` select majors within nixpkgs. Their patch versions follow the lockfile. Changing PostgreSQL's major requires a database migration. `python3` follows nixpkgs' default Python version. These choices require review separately from the checker's version comparisons.

`peertube` and `peertube-runner` inherit their upstream version from `nixpkgs-unstable`. When refreshing that input, validate the three local PeerTube patches listed in `lib/overlays.nix` and the runner override in `packages/peertube/runner.nix`.

## Claude Code plugin marketplaces

Manual marketplace pins live in the `marketplaces` attrset in `home/modules/llm-assistants/claude-code/plugins.nix`:

| Marketplace               | Upstream                             | Revision selection                 |
| ------------------------- | ------------------------------------ | ---------------------------------- |
| `openai-codex`            | `openai/codex-plugin-cc`             | Release tag, recorded in a comment |
| `claude-plugins-official` | `anthropics/claude-plugins-official` | Default branch, dated comment      |

Each row stores a commit `rev` and extracted-tree `hash`. The checker compares revision prefixes with the commit behind the latest release tag or default branch. It reads the pinned revision from code, so an inaccurate tag comment cannot make a stale source appear current. The Workmux marketplace uses `pkgs.workmux.src` from the locked `llm-agents` input. Common skills use the separate `anthropics-skills` and `openai-skills` inputs.

These revisions control the prebuilt Claude Code cache when `hakula.claude-code.plugins.bundle` is enabled, currently in `devvm`. Bundling sets `CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL`. Unbundled Claude Code fetches the configured marketplaces at runtime, so editing these hashes does not pin its runtime cache.

To update a manual marketplace:

1. Resolve the intended release tag or default branch to a commit. Update `rev` and its tag or date comment together.
2. Obtain the extracted-tree hash. `fetchFromGitHub` requires `--unpack` when prefetching an archive:

   ```bash
   nix hash convert --hash-algo sha256 --to sri "$(
     nix-prefetch-url --unpack 'https://github.com/<owner>/<repo>/archive/<rev>.tar.gz'
   )"
   ```

   Check this invocation against the existing revision and hash when using a different archive URL or fetch method.

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

4. Build `.#packages.x86_64-linux.devvm-docker` to check the assembled Claude Code cache.

## Nix-built packages and fetched helpers

### Overlay packages

These packages are registered in `lib/overlays.nix`. The MCP packages are grouped under `packages/mcp/`:

| Package                 | Location                                         | Upstream                                 |
| ----------------------- | ------------------------------------------------ | ---------------------------------------- |
| `acpx`                  | `packages/acpx/default.nix`                      | `openclaw/acpx` releases                 |
| `cloudreve`             | `packages/cloudreve/default.nix`                 | `cloudreve/cloudreve` releases           |
| `mcp-server-filesystem` | `packages/mcp/mcp-server-filesystem/default.nix` | `modelcontextprotocol/servers` date tags |
| `mcp-server-git`        | `packages/mcp/mcp-server-git/default.nix`        | `mcp-server-git` on PyPI                 |
| `mcp-server-github`     | `packages/mcp/mcp-server-github/default.nix`     | `github/github-mcp-server` releases      |
| `mcp-server-gitlab`     | `packages/mcp/mcp-server-gitlab/default.nix`     | `zereight/gitlab-mcp` releases           |
| `zsh-hist`              | `packages/zsh-hist/default.nix`                  | `marlonrichert/zsh-hist` default branch  |

Update the package's `version` and source hash, preserving its upstream tag convention. `zsh-hist` uses a commit pin, so update `src.rev`, `src.hash`, and the date in its `0-unstable-YYYY-MM-DD` version together.

Hash requirements depend on the fetcher:

- `acpx` needs both the GitHub source hash and `pnpmDeps.hash` from `fetchPnpmDeps`.
- `mcp-server-filesystem` and `mcp-server-gitlab` need the GitHub source hash and `npmDepsHash`. Rebuild to validate dependency hashes even when the upstream lockfile appears unchanged.
- `mcp-server-git` fetches a PyPI source distribution. Check that its declared nixpkgs Python dependencies still satisfy the new release. The package disables upstream tests because its source distribution contains none.
- `cloudreve` and `mcp-server-github` use `fetchurl` for release archives. Update every entry in `sources`, including platforms unavailable locally. Prefetch their archive bytes without `--unpack`. Cloudreve currently supports `x86_64-linux`. The GitHub server also supports `aarch64-darwin`.

Use `lib.fakeHash` temporarily when obtaining a hash from a Nix mismatch error. Build again with the reported hash, resolving dependency hashes after the source hash. Never leave a placeholder hash in the final change.

The custom packages are overlay attributes and are not exposed as individual flake package outputs. Build through the overlay, replacing `p.acpx` with the desired attribute and selecting a supported system:

```bash
nix build --no-link --print-out-paths --impure --expr '
  let
    f = builtins.getFlake (toString ./.);
    p = import f.inputs.nixpkgs {
      system = "x86_64-linux";
      overlays = import ./lib/overlays.nix {
        inherit (f) inputs;
        nixpkgs-unstable = f.inputs.nixpkgs-unstable;
      };
      config.allowUnfree = true;
    };
  in
  p.acpx
'
```

For executable packages, run a supported `--version` or `--help` command from the resulting store path to catch wrapper, entry-point, or loader failures. `zsh-hist` installs a Zsh plugin under `share/zsh-hist` and has no executable. Verify its loading and `hist` command in an isolated Zsh session without modifying the user's history.

### Windows notification helper

`toasty` is a local binding in `home/modules/llm-assistants/shared/notify/default.nix`, fetched from `shanselman/toasty`. Update the release tag in its URL and the `fetchurl` hash together. The checker selects the newest release with `toasty-x64.exe`, since some releases omit that asset.

This helper is not exported as an overlay attribute. Build a Linux host that enables assistant notifications, such as `wsl`, to validate the fetch and wrapper. Runtime notification verification requires Windows interoperability in WSL.

## Container images and runtime packages

### Container images

The default `image` options contain the tags checked by the script:

| Service    | Location                             | Upstream                           |
| ---------- | ------------------------------------ | ---------------------------------- |
| `clove`    | `modules/nixos/clove/default.nix`    | `mirrorange/clove` on Docker Hub   |
| `fuclaude` | `modules/nixos/fuclaude/default.nix` | `pengzhile/fuclaude` on Docker Hub |
| `umami`    | `modules/nixos/umami/default.nix`    | `umami-software/umami` releases    |

Only Umami is enabled in the current host definitions, on `us-4`. The other two modules are dormant. Inspect host overrides before changing a default, since the checker does not evaluate effective host image options.

Review release notes for application and database migrations, then edit the tag and build the affected host. Nix builds validate the service configuration but do not fetch these container images or test their runtime. When deployment is requested, `colmena apply --on us-4` applies an Umami update. Podman resolves the configured image when starting the container.

### PicList

`modules/nixos/piclist/server/default.nix` pins the npm package version. Its startup script compares that value with the installed package and reinstalls on a mismatch or missing executable. Bump `version` and build the affected host, currently `us-4`. The npm install occurs at service start, so successful host builds do not validate package availability or runtime compatibility.

### Unpinned MCP wrappers

The `npx` and `uvx` MCP wrappers in `home/modules/llm-assistants/shared/mcp/default.nix` leave versions unspecified, including `mcp-atlassian` and `scrapling[ai]`. Their runtime resolution and caches are outside this pin checker.

## GitHub Actions

External actions use major tags in `.github/workflows/` and `.github/actions/setup-nix/action.yml`: `actions/checkout`, `anthropics/claude-code-action`, `cachix/cachix-action`, `cachix/install-nix-action`, and `wimpysworld/nothing-but-nix`.

The checker reads workflow jobs, their steps, and composite-action steps from YAML. Major tags compare with the major component of the latest release, while full `vMAJOR.MINOR.PATCH` tags compare with the full release tag. Other GitHub refs, such as commit hashes or branch names, report `UNKNOWN` and need manual review. Local actions and Docker action references are outside this comparison.

Review breaking changes before editing `uses:`. Upstream can move an existing major tag without a repository change. Run local workflow checks, then verify an actual GitHub Actions run for runtime behavior. A GitLab-only MR does not trigger GitHub CI. See [CI](../../../docs/reference/ci.md) for triggers.

## Cloudflare IP ranges

`modules/nixos/cloudflare/ips.nix` snapshots the ranges used by nginx's real IP configuration. The checker compares the range sets, using the `Last updated` comment only as the displayed local value.

```bash
curl -fsS https://www.cloudflare.com/ips-v4
curl -fsS https://www.cloudflare.com/ips-v6
```

Update both lists and the date after confirming both requests succeeded. Every server enables nginx through `hosts/_profiles/role/server`, so the affected configuration spans the server fleet. Validate server builds. When a fleet deployment is requested, `colmena apply` applies the change.

## Verification

Follow [repository verification](../../../AGENTS.md#verification) for formatting and builds. Select checks by the changed source: direct package or marketplace fetches first, then the affected host or plugin bundle. A source fetch for another platform verifies its hash but does not prove its binary runs there.

Report which pins changed, the upstream releases or commits selected, and the checks actually completed. Keep incomplete upstream queries and untested runtime or deployment behavior explicit.
