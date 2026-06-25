# ==============================================================================
# Systemd Helper Library
# ==============================================================================

{
  hardening = {
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    ProtectControlGroups = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
  };
}
