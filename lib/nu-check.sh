#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Nushell Diagnostic Check
# ==============================================================================
# Wraps `nu --ide-check`, which reports diagnostics as JSON on stdout but always
# exits 0. Turns an Error-severity diagnostic into a non-zero exit so pre-commit
# can gate on it.
# ==============================================================================

readonly NU="@nu@"
readonly MAX_ERRORS=100

rc=0
for file in "$@"; do
  output="$("${NU}" --ide-check "${MAX_ERRORS}" "${file}" 2>&1)" || true

  errors="$(printf '%s\n' "${output}" | grep '"severity":"Error"' || true)"
  if [[ -n "${errors}" ]]; then
    printf '%s:\n' "${file}" >&2
    printf '%s\n' "${errors}" \
      | "@jq@" -r '"  \(.message) (offset \(.span.start))"' >&2
    rc=1
  fi
done

exit "${rc}"
