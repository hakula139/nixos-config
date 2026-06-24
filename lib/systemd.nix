# ==============================================================================
# Systemd Helper Library
# ==============================================================================

let
  base = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    ProtectControlGroups = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
  };
in
{
  hardening = {
    inherit base;
    strict = base // {
      RestrictSUIDSGID = true;
      LockPersonality = true;
      UMask = "0077";
    };
  };
}
