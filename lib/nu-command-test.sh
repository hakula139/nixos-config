#!/usr/bin/env bash

# ==================================================================================================
# Nushell Command Guard Test
# ==================================================================================================

set -euo pipefail

executable=$1
marker="$TMPDIR/marker"
injection="--help;^touch $marker"

check-rejected() {
  status=0
  "$@" >/dev/null 2>"$TMPDIR/stderr" || status=$?
  if [[ "$status" -ne 1 ]]; then
    echo "expected exit 1, got $status: $*" >&2
    cat "$TMPDIR/stderr" >&2
    exit 1
  fi
  if ! grep -q 'Nushell would parse this argument as code' "$TMPDIR/stderr"; then
    echo "expected the guard message: $*" >&2
    cat "$TMPDIR/stderr" >&2
    exit 1
  fi
}

check-rejected "$executable" "$injection"
check-rejected "$executable" doc.md "$injection"

"$executable" "--flag=x;^touch $marker" >/dev/null

if [[ -e "$marker" ]]; then
  echo "injected command ran" >&2
  exit 1
fi

target="$TMPDIR/redirection-marker"
for redirection in 'o>' 'e>' 'err>' 'out+err>'; do
  printf 'keep' >"$target"
  check-rejected "$executable" "$redirection" "$target"
  if [[ "$(cat "$target")" != 'keep' ]]; then
    echo "the $redirection redirection rewrote $target" >&2
    exit 1
  fi
done

# shellcheck disable=SC2016
check-rejected "$executable" '...$env.PATH'

"$executable" --flag value >/dev/null
"$executable" -- >/dev/null
"$executable" --flag=value >/dev/null
