{
  config,
  pkgs,
  inputs,
  ...
}:

# ============================================================================
# Netdata (Monitoring Service)
# ============================================================================

let
  netdataPkgsUnstable = import inputs.nixpkgs-unstable {
    system = pkgs.system;
    config = config.nixpkgs.config;
  };
  netdataPkgUnstable = netdataPkgsUnstable.netdata.override {
    withCloudUi = true;
  };
in
{
  age.secrets.qq-smtp-authcode = {
    file = ../../../secrets/qq-smtp-authcode.age;
    owner = "netdata";
    group = "netdata";
    mode = "0400";
  };

  services.netdata = {
    enable = true;
    package = netdataPkgUnstable;
    config = {
      global = {
        "hostname" = "cloudcone-sc2";
      };
      directories = {
        "web files directory" = "${netdataPkgUnstable}/share/netdata/web";
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
      web = {
        "bind to" = "127.0.0.1:19999";
        "enable gzip compression" = "yes";
      };
    };
  };

  environment.etc."msmtprc" = {
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

  environment.etc."netdata/health_alarm_notify.conf".source = ./health_alarm_notify.conf;

  systemd.services.netdata =
    let
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
          exec ${pkgs.systemd}/bin/systemd-cat -t "$tag" "''${out[@]}"
        else
          exec ${pkgs.systemd}/bin/systemd-cat "''${out[@]}"
        fi
      '';
    in
    {
      path = [
        pkgs.systemd
        systemdCatNative
        pkgs.msmtp
      ];

      environment.NETDATA_PREFIX = "${netdataPkgUnstable}";
    };
}
