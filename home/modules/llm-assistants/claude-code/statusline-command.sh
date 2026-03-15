#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Claude Code Status Line Command
# ==============================================================================
# Row 1: #tty <directory> <git>
# Row 2: [Model] | Ctx: X% (XXk/200k) | Sess: $X.XX | Block: $X.XX (XhYm left, $X.XX/h) | Today: $X.XX | HH:MM
# ==============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BOLD_BLUE='\033[1;34m'
readonly CYAN='\033[0;36m'
readonly DIM='\033[2;37m'
readonly RESET='\033[0m'

# Separator between statusline components
readonly SEP=" ${DIM}|${RESET} "

# Paths substituted by Nix
readonly NPX="@npx@"
readonly GET_TTY_NUM="@getTtyNum@"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

# Prints "Label: value" with dimmed label and colored value
labeled() {
  local label="$1" value="$2" color="${3:-${GREEN}}"
  printf '%b%s:%b %b%s%b' \
    "${DIM}" "${label}" "${RESET}" \
    "${color}" "${value}" "${RESET}"
}

# Joins array elements with separator, skipping empty parts
join_parts() {
  local sep="$1"
  shift

  local result=""
  for part in "$@"; do
    if [[ -z "${part}" ]]; then
      continue
    fi
    if [[ -n "${result}" ]]; then
      result+="${sep}"
    fi
    result+="${part}"
  done

  printf '%b' "${result}"
}

# ------------------------------------------------------------------------------
# Git Info
# ------------------------------------------------------------------------------

format_git_info() {
  local cwd="$1"

  # Check if in git repo
  git -C "${cwd}" rev-parse --git-dir &>/dev/null || return

  local branch
  branch="$(git -C "${cwd}" --no-optional-locks branch --show-current 2>/dev/null)" || return
  [[ -z "${branch}" ]] && return

  # Get divergence counts
  local ahead=0 behind=0
  read -r behind ahead < <(
    git -C "${cwd}" --no-optional-locks rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null || echo "0 0"
  )

  # Get status counts
  local staged=0 modified=0 untracked=0
  while IFS= read -r line; do
    case "${line:0:2}" in
      [MA]?) ((staged++)) ;;
      ' M') ((modified++)) ;;
      '??') ((untracked++)) ;;
    esac
  done < <(git -C "${cwd}" --no-optional-locks status --porcelain 2>/dev/null)

  # Build status string
  local status=""
  ((ahead > 0)) && status+=" »${ahead}"
  ((behind > 0)) && status+=" «${behind}"
  ((staged > 0)) && status+=" +${staged}"
  ((modified > 0)) && status+=" !${modified}"
  ((untracked > 0)) && status+=" ?${untracked}"

  printf ' %b%s%b' "${GREEN}" "${branch}" "${RESET}"
  if [[ -n "${status}" ]]; then
    printf '%b%s%b' "${YELLOW}" "${status}" "${RESET}"
  fi
  printf ' '
}

# ------------------------------------------------------------------------------
# Context & Session (from Claude Code JSON)
# ------------------------------------------------------------------------------

format_claude_info() {
  local input="$1"

  local data
  data="$(echo "${input}" | jq -r '
    [
      (.context_window.current_usage.input_tokens // 0),
      (.context_window.current_usage.cache_creation_input_tokens // 0),
      (.context_window.current_usage.cache_read_input_tokens // 0),
      (.context_window.context_window_size // 0),
      (.cost.total_cost_usd // 0)
    ] | @tsv
  ')"

  local input_tokens cache_creation cache_read context_size cost_usd
  IFS=$'\t' read -r input_tokens cache_creation cache_read context_size cost_usd <<<"${data}"

  # Context usage
  local ctx_output
  if [[ "${context_size}" -eq 0 ]]; then
    ctx_output="$(labeled "Ctx" "0%")"
  else
    local current_tokens=$((input_tokens + cache_creation + cache_read))
    local percent=$((current_tokens * 100 / context_size))

    local color
    if ((percent >= 80)); then
      color="${RED}"
    elif ((percent >= 50)); then
      color="${YELLOW}"
    else
      color="${GREEN}"
    fi

    ctx_output="$(
      labeled "Ctx" "${percent}% ($((current_tokens / 1000))k/$((context_size / 1000))k)" "${color}"
    )"
  fi

  # Session cost
  local sess_output
  sess_output="$(labeled "Sess" "$(printf '$%.2f' "${cost_usd}")")"

  printf '%s\t%s' "${ctx_output}" "${sess_output}"
}

# ------------------------------------------------------------------------------
# ccusage Integration
# ------------------------------------------------------------------------------

readonly CCUSAGE_CACHE="/tmp/ccusage-statusline.json"
readonly CCUSAGE_TTL=30 # seconds

get_ccusage_data() {
  # Use cache if fresh
  if [[ -f "${CCUSAGE_CACHE}" ]]; then
    local age=$(($(date +%s) - $(stat -c %Y "${CCUSAGE_CACHE}" 2>/dev/null || echo 0)))
    if ((age < CCUSAGE_TTL)); then
      cat "${CCUSAGE_CACHE}"
      return
    fi
  fi

  local result
  result="$("${NPX}" -y ccusage@latest blocks --json 2>/dev/null | jq -c '
    (now | strftime("%Y-%m-%d")) as $today |
    (.blocks // []) as $blocks |
    ($blocks | map(select(.isActive)) | first) as $active |
    {
      block_cost: ($active.costUSD // 0),
      time_remaining: (($active.projection.remainingMinutes // 0) | floor),
      burn_rate: ($active.burnRate.costPerHour // 0),
      daily_cost: ([$blocks[] | select(.startTime | startswith($today)) | .costUSD] | add // 0),
      has_data: ($active != null)
    }
  ' 2>/dev/null)" || result='{"has_data": false}'

  echo "${result}" | tee "${CCUSAGE_CACHE}"
}

format_ccusage_info() {
  local data="$1"

  local values
  values="$(echo "${data}" | jq -r '[.block_cost, .time_remaining, .burn_rate, .daily_cost, .has_data] | @tsv')"

  local block_cost time_remaining burn_rate daily_cost has_data
  IFS=$'\t' read -r block_cost time_remaining burn_rate daily_cost has_data <<<"${values}"

  [[ "${has_data}" != "true" ]] && return

  # Format time remaining
  local time_str=""
  if ((time_remaining > 0)); then
    local hours=$((time_remaining / 60))
    local mins=$((time_remaining % 60))
    if ((hours > 0)); then
      time_str="${hours}h${mins}m left"
    else
      time_str="${mins}m left"
    fi
  fi

  # Format burn rate
  local rate_str=""
  if [[ "$(echo "${data}" | jq '.burn_rate > 0')" == "true" ]]; then
    rate_str="$(printf '$%.2f/h' "${burn_rate}")"
  fi

  # Build block info with optional details
  local block_output
  block_output="$(labeled "Block" "$(printf '$%.2f' "${block_cost}")" "${CYAN}")"

  if [[ -n "${time_str}" || -n "${rate_str}" ]]; then
    local details="${time_str}"
    if [[ -n "${time_str}" && -n "${rate_str}" ]]; then
      details+=", "
    fi
    details+="${rate_str}"
    block_output+="$(printf ' %b(%s)%b' "${YELLOW}" "${details}" "${RESET}")"
  fi

  # Daily total
  local daily_output
  daily_output="$(labeled "Today" "$(printf '$%.2f' "${daily_cost}")" "${CYAN}")"

  printf '%s\t%s' "${block_output}" "${daily_output}"
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
  local input
  input="$(cat)"

  local cwd
  cwd="$(echo "${input}" | jq -r '.workspace.current_dir')"

  # ----------------------------------------------------------------------------
  # Row 1: tty, directory, git
  # ----------------------------------------------------------------------------
  local tty_num
  tty_num="$("${GET_TTY_NUM}")"

  local dir_name
  if [[ "${cwd}" == "${HOME}" ]]; then
    dir_name="~"
  else
    dir_name="$(basename "${cwd}")"
  fi

  local row1
  row1="$(
    printf '%b#%s%b %b%s%b%s' \
      "${DIM}" "${tty_num}" "${RESET}" \
      "${BOLD_BLUE}" "${dir_name}" "${RESET}" \
      "$(format_git_info "${cwd}")"
  )"

  # ----------------------------------------------------------------------------
  # Row 2: model, context, session, block, daily, time
  # ----------------------------------------------------------------------------
  local model_name
  model_name="$(echo "${input}" | jq -r '.model.display_name // empty')"

  local model_output=""
  if [[ -n "${model_name}" ]]; then
    model_output="$(printf '%b[%s]%b' "${CYAN}" "${model_name}" "${RESET}")"
  fi

  local claude_info ccusage_data ccusage_info
  claude_info="$(format_claude_info "${input}")"
  ccusage_data="$(get_ccusage_data)"
  ccusage_info="$(format_ccusage_info "${ccusage_data}")"

  local ctx sess block daily
  IFS=$'\t' read -r ctx sess <<<"${claude_info}"
  IFS=$'\t' read -r block daily <<<"${ccusage_info}"

  local current_time
  current_time="$(printf '%b%s%b' "${DIM}" "$(date +%H:%M)" "${RESET}")"

  local row2
  row2="$(join_parts "${SEP}" "${model_output}" "${ctx}" "${sess}" "${block}" "${daily}" "${current_time}")"

  printf '%b\n%b' "${row1}" "${row2}"
}

main "$@"
