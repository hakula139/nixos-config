# Claude Code auth profile switcher.
# Lists and switches between authentication profiles by updating the
# active-profile symlink in the state directory.

readonly GREEN='\033[1;32m'
readonly RESET='\033[0m'

readonly PROFILES_DIR="@stateDir@/profiles"
readonly ACTIVE_LINK="@stateDir@/active-profile"

list_profiles() {
  local current
  current="$(readlink "${ACTIVE_LINK}" 2>/dev/null)"
  current="${current##*/}"
  current="${current%.sh}"

  # shellcheck disable=SC2043  # @profileNames@ expands to multiple words at build time
  for name in @profileNames@; do
    if [[ "${name}" == "${current}" ]]; then
      printf '%b\n' "  ${GREEN}* ${name}${RESET} (active)"
    else
      echo "    ${name}"
    fi
  done
}

case "${1:-}" in
  "" | -l | --list)
    list_profiles
    ;;
  -h | --help)
    echo "Usage: claude-switch [<profile> | --list]"
    echo
    echo "Available profiles:"
    list_profiles
    ;;
  *)
    profile="${PROFILES_DIR}/$1.sh"
    if [[ ! -f "${profile}" ]]; then
      echo "Unknown profile: $1" >&2
      echo >&2
      echo "Available profiles:" >&2
      list_profiles >&2
      exit 1
    fi
    ln -sf "${profile}" "${ACTIVE_LINK}"
    echo "Switched to profile: $1"
    echo "Restart Claude Code for changes to take effect."
    ;;
esac
