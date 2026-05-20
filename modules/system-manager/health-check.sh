#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -eq 0 ]]; then
  echo "usage: system-manager-health-check <service>..." >&2
  exit 2
fi

rc=0
for service in "$@"; do
  if ! systemctl list-unit-files "$service" >/dev/null 2>&1; then
    echo "service '$service' is not installed; skipping" >&2
    continue
  fi

  state="$(systemctl show --property=ActiveState --value "$service")"
  type="$(systemctl show --property=Type --value "$service")"
  result="$(systemctl show --property=Result --value "$service")"
  status="$(systemctl show --property=ExecMainStatus --value "$service")"
  started="$(systemctl show --property=ExecMainStartTimestampMonotonic --value "$service")"

  if [[ "$state" == active ]] \
    || {
      [[ "$type" == oneshot ]] \
        && [[ "$result" == success ]] \
        && [[ "$status" == 0 ]] \
        && [[ -n "$started" ]] \
        && [[ "$started" != 0 ]]
    }; then
    continue
  fi

  echo "service '$service' is not active" >&2
  systemctl status --no-pager "$service" >&2 || true
  rc=1
done

exit "$rc"
