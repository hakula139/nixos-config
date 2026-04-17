# Sourced by the Claude Code wrapper at startup. Resets all auth-related
# environment variables, then sources the active profile script.

@unsetVars@

__claude_profile="@stateDir@/active-profile"
if [ -f "$__claude_profile" ]; then
  . "$__claude_profile"
else
  printf 'claude: no active auth profile at %s\n' "$__claude_profile" >&2
fi
