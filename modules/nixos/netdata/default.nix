# ==================================================================================================
# Netdata (Monitoring)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  repoLib,
  ...
}:

let
  cfg = config.hakula.services.netdata;

  netdataPkg = pkgs.netdata;
  yaml = pkgs.formats.yaml { };

  # Nixpkgs renames this plugin to .org for a wrapper that neither module creates.
  systemdUnitsPlugin = pkgs.linkFarm "netdata-systemd-units-plugin" {
    "systemd-units.plugin" = "${netdataPkg}/libexec/netdata/plugins.d/systemd-units.plugin.org";
  };
in
{
  # The unstable package renames go.d.plugin, and only its matching module wraps it back.
  disabledModules = [ "services/monitoring/netdata.nix" ];
  imports = [ "${inputs.nixpkgs-unstable}/nixos/modules/services/monitoring/netdata.nix" ];

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
    # PostgreSQL
    # ----------------------------------------------------------------------------------------------
    services.postgresql.ensureUsers = lib.mkIf config.services.postgresql.enable [
      { name = "netdata"; }
    ];

    systemd.services.postgresql-setup.postStart = lib.mkIf config.services.postgresql.enable ''
      psql -tAc 'GRANT pg_monitor TO netdata'
    '';

    # ----------------------------------------------------------------------------------------------
    # Netdata service
    # ----------------------------------------------------------------------------------------------
    services.netdata = {
      enable = true;
      package = netdataPkg;
      python.enable = false;

      extraPluginPaths = [ systemdUnitsPlugin ];

      configDir = {
        "go.d/httpcheck.conf" = yaml.generate "httpcheck.conf" {
          jobs =
            lib.optional config.hakula.services.cloudreve.enable {
              name = "cloudreve";
              url = "http://127.0.0.1:${toString config.hakula.services.cloudreve.port}/api/v4/site/ping";
            }
            ++ lib.optional config.hakula.services.peertube.enable {
              name = "peertube";
              url = "http://127.0.0.1:${toString config.hakula.services.peertube.port}/api/v1/ping";
            }
            ++ lib.optional config.hakula.services.umami.enable {
              name = "umami";
              url = "http://127.0.0.1:${toString config.hakula.services.umami.port}/api/heartbeat";
            };
        };

        "go.d/nginx.conf" = lib.mkIf config.services.nginx.statusPage (
          yaml.generate "nginx.conf" {
            jobs = [
              {
                name = "local";
                url = "http://127.0.0.1/nginx_status";
              }
            ];
          }
        );

        "go.d/postgres.conf" = lib.mkIf config.services.postgresql.enable (
          yaml.generate "postgres.conf" {
            jobs = [
              {
                name = "local";
                dsn = "host=/run/postgresql dbname=postgres user=netdata";
              }
            ];
          }
        );

        "go.d/x509check.conf" = yaml.generate "x509check.conf" {
          jobs = [
            {
              name = "hakula_xyz";
              # nginx's default server presents the wildcard ACME certificate.
              source = "https://127.0.0.1:8443";
              tls_skip_verify = true;
            }
          ];
        };

        "health_alarm_notify.conf" = pkgs.writeText "health_alarm_notify.conf" ''
          SEND_EMAIL="NO"
        '';
      };

      config = {
        global.hostname = config.networking.hostName;

        db = {
          db = "dbengine";
          "update every" = 2;
          "storage tiers" = 3;
          "dbengine page cache size" = "32MiB";
          "dbengine tier 0 retention size" = "768MiB";
          "dbengine tier 1 retention size" = "256MiB";
          "dbengine tier 2 retention size" = "128MiB";
        };

        plugins = {
          # These KVM guests have no IPMI or ioping targets, and nothing here uses perf counters.
          freeipmi = "no";
          ioping = "no";
          perf = "no";

          # Nixpkgs exposes a dangling wrapper for this unavailable plugin.
          logs-management = "no";

          # No charts.d, python.d, or scripts.d jobs, and no NetFlow, OTLP, StatsD, or tc sources.
          "charts.d" = "no";
          "python.d" = "no";
          "scripts.d" = "no";
          netflow = "no";
          otel = "no";
          statsd = "no";
          tc = "no";
        };

        "plugin:apps"."command options" = "without-users without-groups";

        web."bind to" = "unix:/run/netdata/netdata.sock";
      };
    };

    # ----------------------------------------------------------------------------------------------
    # Systemd service
    # ----------------------------------------------------------------------------------------------
    systemd.services.netdata = lib.mkMerge [
      repoLib.systemd.restartUnit

      {
        path = [ netdataPkg ];
        environment.NETDATA_PREFIX = "${netdataPkg}";
      }
    ];
  };
}
