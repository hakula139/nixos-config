#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Claude Code Status Line Command
# ==============================================================================
# Format: [dir] [git] ❯  Ctx: X% | Sess: $X.XX | Block: $X.XX (XhYm left, $X.XX/h) | Today: $X.XX | HH:MM

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BOLD_GREEN='\033[1;32m'
readonly YELLOW='\033[0;33m'
readonly BOLD_BLUE='\033[1;34m'
readonly CYAN='\033[0;36m'
readonly DIMMED_WHITE='\033[2;37m'
readonly RESET='\033[0m'

# Separator between statusline components
readonly SEP=" ${DIMMED_WHITE}|${RESET} "

# Path to npx - will be substituted by Nix
readonly NPX="@npx@"

# ------------------------------------------------------------------------------
# Utility Functions
# ------------------------------------------------------------------------------

get_directory_display() {
  local cwd="$1"
  if [[ "${cwd}" == "${HOME}" ]]; then
    echo "~"
  else
    basename "${cwd}"
  fi
}

get_git_branch() {
  local cwd="$1"
  git -C "${cwd}" --no-optional-locks branch --show-current 2>/dev/null || true
}

get_git_divergence() {
  local cwd="$1"
  local ahead behind

  read -r ahead behind < <(git -C "${cwd}" --no-optional-locks rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null || echo "0 0")

  local divergence=()
  [[ "${ahead}" -gt 0 ]] && divergence+=("»${ahead}")
  [[ "${behind}" -gt 0 ]] && divergence+=("«${behind}")

  [[ ${#divergence[@]} -gt 0 ]] && printf ' %s' "${divergence[@]}"
}

get_git_status_counts() {
  local cwd="$1"
  local status_output
  status_output="$(git -C "${cwd}" --no-optional-locks status --porcelain 2>/dev/null || true)"

  if [[ -z "${status_output}" ]]; then
    return
  fi

  local staged modified untracked
  staged="$(echo "${status_output}" | grep -c '^[MA]' || true)"
  modified="$(echo "${status_output}" | grep -c '^ M' || true)"
  untracked="$(echo "${status_output}" | grep -c '^??' || true)"

  local status_parts=()
  [[ "${staged}" -gt 0 ]] && status_parts+=("+${staged}")
  [[ "${modified}" -gt 0 ]] && status_parts+=("!${modified}")
  [[ "${untracked}" -gt 0 ]] && status_parts+=("?${untracked}")

  [[ ${#status_parts[@]} -gt 0 ]] && printf ' %s' "${status_parts[@]}"
}

format_git_info() {
  local cwd="$1"

  if [[ ! -d "${cwd}/.git" ]] && ! git -C "${cwd}" rev-parse --git-dir >/dev/null 2>&1; then
    return
  fi

  local branch
  branch="$(get_git_branch "${cwd}")"
  [[ -z "${branch}" ]] && return

  local git_display divergence status_counts
  git_display="$(printf '%b%s%b' "${GREEN}" "${branch}" "${RESET}")"
  divergence="$(get_git_divergence "${cwd}")"
  status_counts="$(get_git_status_counts "${cwd}")"

  local combined_status="${divergence}${status_counts}"
  if [[ -n "${combined_status}" ]]; then
    git_display="${git_display}$(printf '%b%s%b' "${YELLOW}" "${combined_status}" "${RESET}")"
  fi

  printf ' %s ' "${git_display}"
}

# ------------------------------------------------------------------------------
# Context & Cost Formatting (from Claude Code JSON)
# ------------------------------------------------------------------------------

format_context_usage() {
  local input="$1"
  local usage context_size

  usage="$(echo "${input}" | jq '.context_window.current_usage')"
  context_size="$(echo "${input}" | jq -r '.context_window.context_window_size // 0')"

  if [[ "${usage}" == "null" ]] || [[ "${context_size}" -eq 0 ]]; then
    printf '%bCtx:%b %b0%%%b' "${DIMMED_WHITE}" "${RESET}" "${GREEN}" "${RESET}"
    return
  fi

  local current_tokens percent_used
  current_tokens="$(echo "${usage}" | jq '
    (.input_tokens // 0) +
    (.cache_creation_input_tokens // 0) +
    (.cache_read_input_tokens // 0)
  ')"
  percent_used=$((current_tokens * 100 / context_size))

  local color="${GREEN}"
  if [[ "${percent_used}" -ge 80 ]]; then
    color="${RED}"
  elif [[ "${percent_used}" -ge 50 ]]; then
    color="${YELLOW}"
  fi

  printf '%bCtx:%b %b%d%%%b (%dk/%dk)' \
    "${DIMMED_WHITE}" "${RESET}" \
    "${color}" "${percent_used}" "${RESET}" \
    "$((current_tokens / 1000))" "$((context_size / 1000))"
}

format_session_cost() {
  local input="$1"
  local cost_usd
  cost_usd="$(echo "${input}" | jq -r '.cost.total_cost_usd // 0')"
  printf '%bSess:%b %b$%.2f%b' \
    "${DIMMED_WHITE}" "${RESET}" \
    "${GREEN}" "${cost_usd}" "${RESET}"
}

# ------------------------------------------------------------------------------
# ccusage Integration
# ------------------------------------------------------------------------------

readonly CCUSAGE_CACHE_FILE="/tmp/ccusage-statusline-cache.json"
readonly CCUSAGE_CACHE_TTL=30 # seconds

get_ccusage_data() {
  # Check if cache is still valid
  if [[ -f "${CCUSAGE_CACHE_FILE}" ]]; then
    local cache_age
    cache_age="$(($(date +%s) - $(stat -c %Y "${CCUSAGE_CACHE_FILE}" 2>/dev/null || echo 0)))"
    if [[ "${cache_age}" -lt "${CCUSAGE_CACHE_TTL}" ]]; then
      cat "${CCUSAGE_CACHE_FILE}"
      return
    fi
  fi

  # Fetch fresh data from ccusage
  local blocks_json
  blocks_json="$("${NPX}" -y ccusage@latest blocks --json --offline 2>/dev/null || echo '{}')"

  local result
  if [[ -z "${blocks_json}" ]] || [[ "${blocks_json}" == "{}" ]]; then
    result='{"block_cost": 0, "time_remaining": 0, "burn_rate": 0, "daily_cost": 0, "has_data": false}'
  else
    local active_block block_cost time_remaining burn_rate daily_cost has_data
    active_block="$(echo "${blocks_json}" | jq '[.blocks[] | select(.isActive == true)] | first // null')"

    if [[ "${active_block}" != "null" ]]; then
      block_cost="$(echo "${active_block}" | jq -r '.costUSD // 0')"
      time_remaining="$(echo "${active_block}" | jq -r '.projection.remainingMinutes // 0 | floor')"
      burn_rate="$(echo "${active_block}" | jq -r '.burnRate.costPerHour // 0')"
      has_data="true"
    else
      block_cost="0"
      time_remaining="0"
      burn_rate="0"
      has_data="false"
    fi

    # Sum up today's costs from all blocks
    local today
    today="$(date +%Y-%m-%d)"
    daily_cost="$(echo "${blocks_json}" | jq --arg today "${today}" '
      [.blocks[] | select(.startTime | startswith($today)) | .costUSD] | add // 0
    ')"

    result="$(
      jq -n \
        --argjson block_cost "${block_cost:-0}" \
        --argjson time_remaining "${time_remaining:-0}" \
        --argjson burn_rate "${burn_rate:-0}" \
        --argjson daily_cost "${daily_cost:-0}" \
        --argjson has_data "${has_data:-false}" \
        '{block_cost: $block_cost, time_remaining: $time_remaining, burn_rate: $burn_rate, daily_cost: $daily_cost, has_data: $has_data}'
    )"
  fi

  echo "${result}" >"${CCUSAGE_CACHE_FILE}"
  echo "${result}"
}

format_block_info() {
  local ccusage_data="$1"

  local block_cost time_remaining burn_rate has_data
  block_cost="$(echo "${ccusage_data}" | jq -r '.block_cost // 0')"
  time_remaining="$(echo "${ccusage_data}" | jq -r '.time_remaining // 0')"
  burn_rate="$(echo "${ccusage_data}" | jq -r '.burn_rate // 0')"
  has_data="$(echo "${ccusage_data}" | jq -r '.has_data // false')"

  if [[ "${has_data}" != "true" ]]; then
    return
  fi

  # Format time remaining as XhYm left
  local time_display=""
  if [[ "${time_remaining}" -gt 0 ]]; then
    local hours=$((time_remaining / 60))
    local mins=$((time_remaining % 60))
    if [[ "${hours}" -gt 0 ]]; then
      time_display="${hours}h${mins}m left"
    else
      time_display="${mins}m left"
    fi
  fi

  # Format burn rate
  local rate_display=""
  if [[ "$(echo "${burn_rate} > 0" | bc -l 2>/dev/null || echo 0)" == "1" ]]; then
    rate_display="$(printf '$%.2f/h' "${burn_rate}")"
  fi

  # Build the block info string
  printf '%bBlock:%b %b$%.2f%b' \
    "${DIMMED_WHITE}" "${RESET}" \
    "${CYAN}" "${block_cost}" "${RESET}"

  # Add time and rate in parentheses if available
  if [[ -n "${time_display}" ]] || [[ -n "${rate_display}" ]]; then
    local details=""
    [[ -n "${time_display}" ]] && details="${time_display}"
    if [[ -n "${rate_display}" ]]; then
      [[ -n "${details}" ]] && details+=", "
      details+="${rate_display}"
    fi
    printf ' %b(%s)%b' "${YELLOW}" "${details}" "${RESET}"
  fi
}

format_daily_total() {
  local ccusage_data="$1"

  local daily_cost has_data
  daily_cost="$(echo "${ccusage_data}" | jq -r '.daily_cost // 0')"
  has_data="$(echo "${ccusage_data}" | jq -r '.has_data // false')"

  if [[ "${has_data}" != "true" ]]; then
    return
  fi

  printf '%bToday:%b %b$%.2f%b' \
    "${DIMMED_WHITE}" "${RESET}" \
    "${CYAN}" "${daily_cost}" "${RESET}"
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
  local input cwd
  input="$(cat)"
  cwd="$(echo "${input}" | jq -r '.workspace.current_dir')"

  local ccusage_data
  ccusage_data="$(get_ccusage_data)"

  # Left side
  local dir_display git_info prompt_symbol
  dir_display="$(get_directory_display "${cwd}")"
  git_info="$(format_git_info "${cwd}")"
  prompt_symbol="$(printf '%b❯%b' "${BOLD_GREEN}" "${RESET}")"

  local left_side
  left_side="$(printf '%b%s%b%s%s' "${BOLD_BLUE}" "${dir_display}" "${RESET}" "${git_info}" "${prompt_symbol}")"

  # Right side
  local context_usage session_cost block_info daily_total current_time
  context_usage="$(format_context_usage "${input}")"
  session_cost="$(format_session_cost "${input}")"
  block_info="$(format_block_info "${ccusage_data}")"
  daily_total="$(format_daily_total "${ccusage_data}")"
  current_time="$(printf '%b%s%b' "${DIMMED_WHITE}" "$(date +%H:%M)" "${RESET}")"

  # Build right side with separators
  local right_parts=()
  right_parts+=("${context_usage}")
  right_parts+=("${session_cost}")
  [[ -n "${block_info}" ]] && right_parts+=("${block_info}")
  [[ -n "${daily_total}" ]] && right_parts+=("${daily_total}")
  right_parts+=("${current_time}")

  # Join with separators
  local right_side=""
  for i in "${!right_parts[@]}"; do
    if [[ "${i}" -gt 0 ]]; then
      right_side+="${SEP}"
    fi
    right_side+="${right_parts[${i}]}"
  done

  printf '%b  %b' "${left_side}" "${right_side}"
}

main "$@"
