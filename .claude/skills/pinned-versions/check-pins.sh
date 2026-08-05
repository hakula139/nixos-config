#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Pinned Version Drift Check
# ==============================================================================
# Compare every manually pinned version in this repo against its upstream and
# report which ones have drifted. Renovate-managed pins (flake.lock) are out of
# scope. See SKILL.md for why.
#
# Subcommands:
#   check       Report drift for all pin groups (default)
#   list        Print the pin registry without querying upstreams
# ==============================================================================

REPO_ROOT="$(git rev-parse --show-toplevel)"
readonly REPO_ROOT

readonly PLUGINS_NIX="home/modules/llm-assistants/claude-code/plugins.nix"
readonly CF_IPS_NIX="modules/nixos/cloudflare/ips.nix"

readonly CF_IPS_V4_URL="https://www.cloudflare.com/ips-v4"
readonly CF_IPS_V6_URL="https://www.cloudflare.com/ips-v6"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

stale_count=0
unknown_count=0

report() {
  local name="$1" current="$2" upstream="$3" status="${4:-}"

  if [[ -z "$status" ]]; then
    if [[ -z "$current" || -z "$upstream" ]]; then
      status="UNKNOWN"
    elif [[ "$current" == "$upstream" ]]; then
      status="ok"
    else
      status="STALE"
    fi
  fi

  case "$status" in
    STALE) ((stale_count += 1)) ;;
    UNKNOWN) ((unknown_count += 1)) ;;
  esac

  printf '%-28s %-22s %-22s %s\n' \
    "$name" "${current:-?}" "${upstream:-?}" "$status"
}

section() {
  printf '\n%s\n' "$1"
  printf '%-28s %-22s %-22s %s\n' PIN PINNED UPSTREAM STATUS
}

gh_latest_release() {
  gh api "repos/$1/releases/latest" --jq '.tag_name' 2>/dev/null || true
}

# Upstream's newest release may ship no binaries, which is not a bumpable target.
gh_latest_release_with_asset() {
  gh api "repos/$1/releases?per_page=100" \
    --jq "[.[] | select(.assets | any(.name == \"$2\"))] | first | .tag_name // empty" \
    2>/dev/null || true
}

gh_default_head() {
  local repo="$1" branch
  branch="$(gh api "repos/${repo}" --jq '.default_branch' 2>/dev/null)" || return 0
  [[ -n "$branch" ]] || return 0
  gh api "repos/${repo}/commits/${branch}" --jq '.sha' 2>/dev/null || true
}

gh_latest_semver_tag() {
  gh api "repos/$1/tags?per_page=100" \
    --jq '[.[].name | select(test("^v?[0-9]+(\\.[0-9]+)*$"))] | first' \
    2>/dev/null || true
}

dockerhub_latest_semver() {
  curl -fsS "https://hub.docker.com/v2/repositories/$1/tags?page_size=100" 2>/dev/null \
    | jq -r '
        [.results[].name | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))]
        | sort_by(split(".") | map(tonumber))
        | last // empty
      ' 2>/dev/null || true
}

npm_latest() {
  curl -fsS "https://registry.npmjs.org/$1/latest" 2>/dev/null \
    | jq -r '.version // empty' 2>/dev/null || true
}

pypi_latest() {
  curl -fsS "https://pypi.org/pypi/$1/json" 2>/dev/null \
    | jq -r '.info.version // empty' 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# Pin extraction
# ------------------------------------------------------------------------------

plugin_rev() {
  sed -n "/^    $1 = {/,/^    };/p" "${REPO_ROOT}/${PLUGINS_NIX}" \
    | grep -oP 'rev = "\K[0-9a-f]+' || true
}

nix_version() {
  grep -m1 -oP '^\s*version = "\K[^"]+' "${REPO_ROOT}/$1" || true
}

# Stays empty on extraction failure, so a broken pattern reports UNKNOWN.
nix_version_v() {
  local v
  v="$(nix_version "$1")"
  [[ -n "$v" ]] && printf 'v%s' "$v"
}

image_tag() {
  sed -n '/image = lib.mkOption/,/};/p' "${REPO_ROOT}/$1" \
    | grep -m1 -oP 'default = "[^"]*:\K[^"]+' || true
}

action_pins() {
  grep -rhoP 'uses: \K[A-Za-z0-9._-]+/[A-Za-z0-9._-]+@v[0-9]+' \
    "${REPO_ROOT}/.github/workflows" "${REPO_ROOT}/.github/actions" \
    | sort -u
}

# ------------------------------------------------------------------------------
# Pin groups
# ------------------------------------------------------------------------------

check_plugins() {
  section 'Claude Code plugin marketplaces (rev + hash)'

  local rev tag

  for entry in \
    'agent-browser:vercel-labs/agent-browser' \
    'openai-codex:openai/codex-plugin-cc'; do
    local name="${entry%%:*}" repo="${entry#*:}"
    tag="$(sed -n "/^    ${name} = {/,/^    };/p" "${REPO_ROOT}/${PLUGINS_NIX}" \
      | grep -oP 'rev = "[0-9a-f]+"; # \K\S+' || true)"
    report "$name" "$tag" "$(gh_latest_release "$repo")"
  done

  # These two track a branch, so any newer HEAD counts as drift.
  for entry in \
    'claude-plugins-official:anthropics/claude-plugins-official' \
    'context7-marketplace:upstash/context7'; do
    local name="${entry%%:*}" repo="${entry#*:}"
    rev="$(plugin_rev "$name")"
    local head
    head="$(gh_default_head "$repo")"
    report "$name" "${rev:0:12}" "${head:0:12}"
  done

  report anthropic-agent-skills 'flake.lock' 'flake.lock' renovate
  report workmux 'flake.lock' 'flake.lock' renovate
}

check_packages() {
  section 'Custom packages (packages/)'

  report cloudreve \
    "$(nix_version packages/cloudreve/default.nix)" \
    "$(gh_latest_release cloudreve/cloudreve)"

  report mcp-server-github \
    "$(nix_version_v packages/mcp/mcp-server-github/default.nix)" \
    "$(gh_latest_release github/github-mcp-server)"

  report mcp-server-gitlab \
    "$(nix_version_v packages/mcp/mcp-server-gitlab/default.nix)" \
    "$(gh_latest_release zereight/gitlab-mcp)"

  report mcp-server-filesystem \
    "$(nix_version packages/mcp/mcp-server-filesystem/default.nix)" \
    "$(gh_latest_semver_tag modelcontextprotocol/servers)"

  report mcp-server-git \
    "$(nix_version packages/mcp/mcp-server-git/default.nix)" \
    "$(pypi_latest mcp-server-git)"

  local zsh_hist_rev zsh_hist_head
  zsh_hist_rev="$(grep -m1 -oP 'rev = "\K[0-9a-f]+' "${REPO_ROOT}/packages/zsh-hist/default.nix" || true)"
  zsh_hist_head="$(gh_default_head marlonrichert/zsh-hist)"
  report zsh-hist "${zsh_hist_rev:0:12}" "${zsh_hist_head:0:12}"
}

check_containers() {
  section 'Container images (oci-containers image options)'

  report umami \
    "$(image_tag modules/nixos/umami/default.nix)" \
    "$(gh_latest_release umami-software/umami | sed 's/^v//')"

  report fuclaude \
    "$(image_tag modules/nixos/fuclaude/default.nix)" \
    "$(dockerhub_latest_semver pengzhile/fuclaude)"

  report clove \
    "$(image_tag modules/nixos/clove/default.nix)" \
    "$(dockerhub_latest_semver mirrorange/clove)"
}

check_runtime() {
  section 'Runtime-installed packages'

  report piclist \
    "$(nix_version modules/nixos/piclist/server/default.nix)" \
    "$(npm_latest piclist)"

  report toasty \
    "$(grep -m1 -oP 'download/\Kv?[0-9.]+' "${REPO_ROOT}/home/modules/llm-assistants/shared/notify.nix" || true)" \
    "$(gh_latest_release_with_asset shanselman/toasty toasty-x64.exe)"
}

check_actions() {
  section 'GitHub Actions (Renovate github-actions manager is disabled)'

  local pin repo current upstream
  while IFS= read -r pin; do
    repo="${pin%@*}"
    current="${pin#*@}"
    upstream="$(gh_latest_release "$repo")"
    # Actions are pinned to a major tag, so compare only the major component.
    report "$repo" "$current" "${upstream%%.*}"
  done < <(action_pins)
}

check_cloudflare() {
  section 'Drifting upstream data'

  local pinned upstream
  pinned="$(grep -oP '"\K[0-9a-f.:]+/[0-9]+' "${REPO_ROOT}/${CF_IPS_NIX}" | sort)"
  # ips-v4 ends without a newline, so concatenating would splice its last range
  # onto the first v6 one.
  upstream="$({
    curl -fsS "$CF_IPS_V4_URL" && echo
    curl -fsS "$CF_IPS_V6_URL"
  } 2>/dev/null | grep -v '^$' | sort || true)"

  if [[ -z "$upstream" ]]; then
    report cloudflare-ips "$(grep -oP 'Last updated: \K\S+' "${REPO_ROOT}/${CF_IPS_NIX}")" '' UNKNOWN
  elif [[ "$pinned" == "$upstream" ]]; then
    report cloudflare-ips "$(grep -oP 'Last updated: \K\S+' "${REPO_ROOT}/${CF_IPS_NIX}")" 'same ranges' ok
  else
    report cloudflare-ips "$(grep -oP 'Last updated: \K\S+' "${REPO_ROOT}/${CF_IPS_NIX}")" 'ranges differ' STALE
  fi
}

# ------------------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------------------

cmd_list() {
  printf 'Manual pins tracked by this script:\n\n'
  printf '  %s\n' \
    "plugin marketplaces   ${PLUGINS_NIX}" \
    'custom packages       packages/**/default.nix' \
    'container images      modules/nixos/{umami,fuclaude,clove}/default.nix' \
    'runtime installs      modules/nixos/piclist/server, shared/notify.nix' \
    'github actions        .github/workflows, .github/actions' \
    "upstream data         ${CF_IPS_NIX}"
  printf '\nRenovate covers the 13 flake.lock inputs separately.\n'
}

cmd_check() {
  command -v gh >/dev/null || die 'gh not found. Run inside "nix develop" or install it.'
  command -v jq >/dev/null || die 'jq not found. Run inside "nix develop" or install it.'
  gh auth status >/dev/null 2>&1 || die 'gh is not authenticated. Run "gh auth login".'

  check_plugins
  check_packages
  check_containers
  check_runtime
  check_actions
  check_cloudflare

  printf '\n%d stale, %d unknown.\n' "$stale_count" "$unknown_count"
  if ((unknown_count > 0)); then
    printf 'UNKNOWN means the upstream query failed. Re-check those by hand.\n'
    return 2
  fi
  ((stale_count == 0))
}

case "${1:-check}" in
  check) cmd_check ;;
  list) cmd_list ;;
  -h | --help)
    printf 'Usage: check-pins.sh [check|list]\n'
    ;;
  *) die "unknown subcommand: $1" ;;
esac
