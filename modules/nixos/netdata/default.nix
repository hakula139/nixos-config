# ==================================================================================================
# Netdata (Monitoring)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  ...
}:

let
  cfg = config.hakula.services.netdata;

  netdataPkg = pkgs.netdata;

  systemdCatNative = pkgs.writeShellScriptBin "systemd-cat-native" ''
    tag=""
    out=()
    for arg in "$@"; do
      if [ "$arg" = "--log-as-netdata" ]; then
        tag="netdata"
      else
        out+=("$arg")
      fi
    done

    if [ -n "$tag" ]; then
      exec ${lib.getExe' pkgs.systemd "systemd-cat"} -t "$tag" "''${out[@]}"
    else
      exec ${lib.getExe' pkgs.systemd "systemd-cat"} "''${out[@]}"
    fi
  '';

  sendmail = pkgs.writeShellScriptBin "sendmail" ''
    exec ${lib.getExe pkgs.msmtp} "$@"
  '';
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.services.netdata = {
    enable = lib.mkEnableOption "Netdata monitoring system";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # ----------------------------------------------------------------------------------------------
    # Users & Groups
    # ----------------------------------------------------------------------------------------------
    # Nixpkgs adds podman whenever it is enabled, and its socket is root-equivalent.
    users.users.netdata.extraGroups = lib.mkForce [ ];

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    age.secrets.qq-smtp-authcode = repoLib.secrets.mkSecret {
      name = "netdata/qq-smtp-authcode";
      owner = "netdata";
      group = "netdata";
    };

    # ----------------------------------------------------------------------------------------------
    # Netdata service
    # ----------------------------------------------------------------------------------------------
    services.netdata = {
      enable = true;
      package = netdataPkg;
      python.enable = false;

      config = {
        global = {
          hostname = config.networking.hostName;
        };

        db = {
          "update every" = 2;
          "mode" = "dbengine";
          "storage tiers" = 2;
          "dbengine page cache size MB" = 32;
          "dbengine disk space MB" = 768;
          "dbengine tier 1 update every iterations" = 60;
          "dbengine tier 1 page cache size MB" = 16;
          "dbengine tier 1 disk space MB" = 256;
        };

        plugins = {
          # These KVM guests have no IPMI or ioping targets, and nothing here uses perf counters.
          "freeipmi" = "no";
          "perf" = "no";
          "ioping" = "no";
          # Nixpkgs exposes a dangling wrapper for this unavailable plugin.
          "logs-management" = "no";
          # No NetFlow, OTLP, StatsD, tc, or Nagios sources, and no charts.d or python.d jobs.
          "charts.d" = "no";
          "netflow" = "no";
          "otel" = "no";
          "python.d" = "no";
          "scripts.d" = "no";
          "statsd" = "no";
          "tc" = "no";
        };

        web = {
          "bind to" = "unix:/run/netdata/netdata.sock";
        };
      };
    };

    # ----------------------------------------------------------------------------------------------
    # Systemd service
    # ----------------------------------------------------------------------------------------------
    systemd.services.netdata = lib.mkMerge [
      repoLib.systemd.restartUnit

      {
        path = [
          pkgs.systemd
          systemdCatNative
          pkgs.msmtp
          sendmail
        ];

        environment.NETDATA_PREFIX = "${netdataPkg}";
      }
    ];

    environment.systemPackages = [
      systemdCatNative
      sendmail
    ];

    # ----------------------------------------------------------------------------------------------
    # Email notification
    # ----------------------------------------------------------------------------------------------
    environment.etc.msmtprc = {
      mode = "0444";
      text = ''
        defaults
        auth on
        tls on
        tls_starttls off
        tls_trust_file ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt

        account qq
        host smtp.qq.com
        port 465
        from hakula139@qq.com
        user hakula139@qq.com
        passwordeval "cat ${config.age.secrets.qq-smtp-authcode.path}"

        account default : qq
      '';
    };

    services.netdata.configDir."health_alarm_notify.conf" = pkgs.writeText "health_alarm_notify.conf" ''
      SEND_EMAIL="YES"
      DEFAULT_RECIPIENT_EMAIL="hakula139@qq.com"
      EMAIL_SENDER="hakula139@qq.com"
    '';
  };
}
