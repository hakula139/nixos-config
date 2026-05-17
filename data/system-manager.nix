# ==============================================================================
# System Manager Runtime Layout
# ==============================================================================
{
  # PATH entries provisioned by system-manager activation. $USER expands at
  # shell time so the same list works for any user that sources it.
  systemPaths = [
    "/run/wrappers/bin"
    "/etc/profiles/per-user/$USER/bin"
    "/run/system-manager/sw/bin"
  ];
}
