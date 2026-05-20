#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -eq 0 ]]; then
  echo "usage: system-manager-health-check <service>..." >&2
  exit 2
fi

declare -A unit=()

load_unit() {
  local key service value
  service="$1"
  unit=()

  while IFS='=' read -r key value; do
    unit["$key"]="$value"
  done < <(
    systemctl show \
      --property=ActiveState \
      --property=ExecMainStartTimestampMonotonic \
      --property=ExecMainStatus \
      --property=LoadState \
      --property=Result \
      --property=Type \
      "$service"
  )
}

unit_is_installed() {
  local load_state="${unit[LoadState]:-}"
  [[ -n "$load_state" && "$load_state" != not-found ]]
}

unit_is_successful_oneshot() {
  local started="${unit[ExecMainStartTimestampMonotonic]:-}"

  [[ "${unit[Type]:-}" == oneshot ]] || return 1
  [[ "${unit[Result]:-}" == success ]] || return 1
  [[ "${unit[ExecMainStatus]:-}" == 0 ]] || return 1
  [[ -n "$started" && "$started" != 0 ]]
}

unit_is_healthy() {
  [[ "${unit[ActiveState]:-}" == active ]] || unit_is_successful_oneshot
}

rc=0
for service in "$@"; do
  load_unit "$service"

  if ! unit_is_installed; then
    echo "service '$service' is not installed; skipping" >&2
    continue
  fi

  if unit_is_healthy; then
    continue
  fi

  echo "service '$service' is not active" >&2
  systemctl status --no-pager "$service" >&2 || true
  rc=1
done

exit "$rc"
