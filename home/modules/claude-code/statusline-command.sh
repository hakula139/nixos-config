#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Claude Code Status Line Command
# ==============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BOLD_GREEN='\033[1;32m'
readonly YELLOW='\033[0;33m'
readonly BOLD_BLUE='\033[1;34m'
readonly CYAN='\033[0;36m'
readonly DIMMED_WHITE='\033[2;37m'
readonly RESET='\033[0m'

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

  # Get commits ahead / behind from tracking branch
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
    printf '%b0%%%b' "${GREEN}" "${RESET}"
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

  printf '%b%d%% (%dk/%dk)%b' "${color}" "${percent_used}" "$((current_tokens / 1000))" "$((context_size / 1000))" "${RESET}"
}

format_session_cost() {
  local input="$1"
  local cost_usd
  cost_usd="$(echo "${input}" | jq -r '.cost.total_cost_usd // 0')"
  printf '$%.2f' "${cost_usd}"
}

# ------------------------------------------------------------------------------
# ccusage Integration (for daily totals and block time)
# ------------------------------------------------------------------------------

# Cache ccusage data to avoid calling npx on every statusline update
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
    result='{"daily_cost": 0, "time_remaining": "", "has_data": false}'
  else
    # Extract active block info and calculate daily total
    local active_block daily_cost time_remaining has_data
    active_block="$(echo "${blocks_json}" | jq '[.blocks[] | select(.isActive == true)] | first // null')"

    if [[ "${active_block}" != "null" ]]; then
      # Format remaining minutes as "HH:mm"
      local remaining_mins
      remaining_mins="$(echo "${active_block}" | jq -r '.projection.remainingMinutes // 0 | floor')"
      if [[ "${remaining_mins}" -gt 0 ]]; then
        local hours=$((remaining_mins / 60))
        local mins=$((remaining_mins % 60))
        time_remaining="$(printf '%02d:%02d' "${hours}" "${mins}")"
      else
        time_remaining=""
      fi
      has_data="true"
    else
      time_remaining=""
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
        --argjson daily_cost "${daily_cost:-0}" \
        --arg time_remaining "${time_remaining}" \
        --argjson has_data "${has_data:-false}" \
        '{daily_cost: $daily_cost, time_remaining: $time_remaining, has_data: $has_data}'
    )"
  fi

  # Update cache
  echo "${result}" >"${CCUSAGE_CACHE_FILE}"
  echo "${result}"
}

format_cost_display() {
  local session_cost="$1"
  local ccusage_data="$2"

  local daily_cost has_data
  daily_cost="$(echo "${ccusage_data}" | jq -r '.daily_cost // 0')"
  has_data="$(echo "${ccusage_data}" | jq -r '.has_data // false')"

  if [[ "${has_data}" == "true" ]]; then
    printf '%b%s%b/%b$%.2f%b' "${GREEN}" "${session_cost}" "${RESET}" "${CYAN}" "${daily_cost}" "${RESET}"
  else
    printf '%b%s%b' "${GREEN}" "${session_cost}" "${RESET}"
  fi
}

format_block_time() {
  local ccusage_data="$1"
  local time_remaining
  time_remaining="$(echo "${ccusage_data}" | jq -r '.time_remaining // ""')"

  if [[ -n "${time_remaining}" ]] && [[ "${time_remaining}" != "null" ]]; then
    printf '%b%s%b' "${YELLOW}" "${time_remaining}" "${RESET}"
  fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
  local input cwd
  input="$(cat)"
  cwd="$(echo "${input}" | jq -r '.workspace.current_dir')"

  # Get ccusage data in background for daily / block info
  local ccusage_data
  ccusage_data="$(get_ccusage_data)"

  # Format components
  local dir_display git_info prompt_symbol
  dir_display="$(get_directory_display "${cwd}")"
  git_info="$(format_git_info "${cwd}")"
  prompt_symbol="$(printf '%b❯%b' "${BOLD_GREEN}" "${RESET}")"

  local context_usage session_cost cost_display block_time current_time
  context_usage="$(format_context_usage "${input}")"
  session_cost="$(format_session_cost "${input}")"
  cost_display="$(format_cost_display "${session_cost}" "${ccusage_data}")"
  block_time="$(format_block_time "${ccusage_data}")"
  current_time="$(date +%H:%M)"

  # Build output
  local left_side right_side
  left_side="$(printf '%b%s%b%s%s' "${BOLD_BLUE}" "${dir_display}" "${RESET}" "${git_info}" "${prompt_symbol}")"

  # Build right side with optional block time
  if [[ -n "${block_time}" ]]; then
    right_side="$(printf '%s  %s  %s  %b%s%b' "${context_usage}" "${cost_display}" "${block_time}" "${DIMMED_WHITE}" "${current_time}" "${RESET}")"
  else
    right_side="$(printf '%s  %s  %b%s%b' "${context_usage}" "${cost_display}" "${DIMMED_WHITE}" "${current_time}" "${RESET}")"
  fi

  printf '%s  %s' "${left_side}" "${right_side}"
}

main "$@"
