# shellcheck shell=bash

# ==================================================================================================
# Nushell Wrapper Guard
# ==================================================================================================
# Nushell runs a script's `main` by splicing the arguments into source text, quoting an argument
# only when it holds a separator, bracket, or quote or starts with `$`. The flag name of an argument
# starting with `--`, a bare redirection such as `o>`, and a `...$` spread therefore take effect, so
# `--help;cmd` would run `cmd`.
# ==================================================================================================

flag='^--([A-Za-z][A-Za-z0-9_-]*(=.*)?)?$'
redirection='^(o|out|e|err|o\+e|e\+o|out\+err|err\+out)>>?$'
for arg in "$@"; do
  if [[ "$arg" == --* && ! "$arg" =~ $flag ]] \
    || [[ "$arg" =~ $redirection ]] \
    || [[ "$arg" == '...$'* ]]; then
    echo "${0##*/}: Nushell would parse this argument as code: $arg" >&2
    exit 1
  fi
done
