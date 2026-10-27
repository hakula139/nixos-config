# ==================================================================================================
# Systemd Helper Library
# ==================================================================================================

{
  lib,
}:

let
  # on-failure treats the exit after earlyoom's SIGTERM as clean. systemd resets the backoff only on
  # a manual start, so the cap bounds every later recovery.
  restart = {
    Restart = "always";
    RestartSec = "5s";
    RestartSteps = 4;
    RestartMaxDelaySec = "1min";
  };
in
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

  inherit restart;

  # A zero burst avoids the start-limit-hit latch, whose state needs a manual reset.
  restartUnit = {
    serviceConfig = lib.mapAttrs (_: lib.mkForce) restart;
    unitConfig.StartLimitBurst = lib.mkForce 0;
  };
}
