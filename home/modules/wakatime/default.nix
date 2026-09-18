# ==============================================================================
# WakaTime Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  isDesktop ? false,
  enableDevToolchains ? false,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin;
  inherit (pkgs.unstable) wakatime-cli;
  homeDir = config.home.homeDirectory;

  wakatimeCli = lib.getExe wakatime-cli;

  syncScript = pkgs.writeShellScript "wakatime-sync-ai-activity" ''
    set -euo pipefail
    status=0

    # --sync-offline-activity 0 syncs all queued heartbeats.
    ${wakatimeCli} --sync-offline-activity 0 || status=$?
    ${wakatimeCli} --sync-ai-activity || status=$?

    exit "$status"
  '';
in
{
  config = lib.mkMerge [
    (lib.mkIf isDesktop {
      # ------------------------------------------------------------------------
      # Secrets
      # ------------------------------------------------------------------------
      hakula.secrets.required = {
        "wakatime/config" = {
          path = "${homeDir}/.wakatime.cfg";
        };
      };
    })

    (lib.mkIf (isDesktop || enableDevToolchains) {
      # ------------------------------------------------------------------------
      # Packages
      # ------------------------------------------------------------------------
      home.packages = [ wakatime-cli ];
    })

    (lib.mkIf (isDesktop && !isDarwin) {
      # ------------------------------------------------------------------------
      # Systemd services (Linux)
      # ------------------------------------------------------------------------
      systemd.user.services = {
        wakatime-sync-ai-activity = {
          Unit = {
            Description = "Sync AI assistant activity to WakaTime";
            After = [ "network-online.target" ];
          };

          Service = {
            Type = "oneshot";
            ExecStart = "${syncScript}";
          };
        };
      };

      # ------------------------------------------------------------------------
      # Systemd timer (Linux)
      # ------------------------------------------------------------------------
      systemd.user.timers = {
        wakatime-sync-ai-activity = {
          Unit = {
            Description = "Timer for WakaTime AI activity sync";
          };

          Timer = {
            OnCalendar = "*:0/1";
            Persistent = true;
          };

          Install = {
            WantedBy = [ "timers.target" ];
          };
        };
      };
    })

    (lib.mkIf (isDesktop && isDarwin) {
      # ------------------------------------------------------------------------
      # Launchd agents (macOS)
      # ------------------------------------------------------------------------
      launchd.agents.wakatime-sync-ai-activity = {
        enable = true;
        config = {
          Label = "com.wakatime.sync-ai-activity";
          ProgramArguments = [ "${syncScript}" ];
          StartInterval = 60;
          StandardOutPath = "${homeDir}/Library/Logs/wakatime-sync-ai-activity.log";
          StandardErrorPath = "${homeDir}/Library/Logs/wakatime-sync-ai-activity.log";
        };
      };
    })
  ];
}
