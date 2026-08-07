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
readonly JQ="@jq@"
readonly MAX_ERRORS=100

tmp="$(mktemp -d)"
trap 'rm -rf -- "${tmp}"' EXIT

# Scripts loaded through `builtins.replaceStrings` carry `@name@` placeholders
# that only parse once Nix has substituted them. `[]` stands in because it
# satisfies a `list` parameter and degrades to a string inside quotes, where a
# bare word would trip the type checker.
readonly STUB="${tmp}/stub.nu"
: >"${STUB}"

rc=0
for file in "$@"; do
  if [[ ! -f "${file}" ]]; then
    printf '%s: no such file\n' "${file}" >&2
    rc=1
    continue
  fi

  target="${tmp}/$(basename "${file}")"
  sed -E \
    -e "s|^(use[[:space:]]+)@[a-zA-Z][a-zA-Z0-9]*@|\\1${STUB}|" \
    -e 's|@[a-zA-Z][a-zA-Z0-9]*@|[]|g' \
    "${file}" >"${target}"

  errors="$(
    "${NU}" --ide-check "${MAX_ERRORS}" "${target}" 2>&1 \
      | grep '"severity":"Error"' || true
  )"
  if [[ -n "${errors}" ]]; then
    printf '%s:\n' "${file}" >&2
    printf '%s\n' "${errors}" \
      | "${JQ}" -r '"  \(.message) (offset \(.span.start))"' >&2
    rc=1
  fi
done

exit "${rc}"
