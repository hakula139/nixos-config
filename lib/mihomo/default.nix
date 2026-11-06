# ==================================================================================================
# Mihomo Settings
# ==================================================================================================

{
  lib,
  mkNuCommand,
  proxy,
}:

let
  mixedPort = 7897;
  controllerPort = 59386;
  stateDir = "/var/lib/mihomo";

  mkBaseConfig =
    {
      cfg,
      corpHosts,
      isWork,
      isDarwin,
    }:
    {
      mixed-port = mixedPort;
      external-controller = "127.0.0.1:${toString controllerPort}";

      allow-lan = false;

      mode = "rule";
      log-level = "warning";
      ipv6 = true;
      unified-delay = true;
      tcp-concurrent = true;

      geo-auto-update = true;
      geo-update-interval = 24;

      profile = {
        store-selected = true;
        store-fake-ip = true;
      };

      tun = {
        enable = cfg.tun.enable;
        stack = "gvisor";
        auto-route = true;
        auto-detect-interface = true;
        strict-route = isDarwin;
        mtu = 1500;
        dns-hijack = [
          "any:53"
          "tcp://any:53"
        ];
      }
      // lib.optionalAttrs isDarwin {
        device = "utun1024";
      };

      dns = {
        enable = true;
        prefer-h3 = true;
        ipv6 = true;
        use-system-hosts = true;

        enhanced-mode = "fake-ip";
        fake-ip-range = "198.18.0.1/16";
        fake-ip-range6 = "2001:2::/64";
        fake-ip-filter-mode = "blacklist";
        fake-ip-filter = [
          "+.lan"
          "+.local"
          "+.arpa"
          "time.*.com"
          "ntp.*.com"
          "+.pool.ntp.org"
          "+.msftconnecttest.com"
          "+.msftncsi.com"
          "localhost.ptlogin2.qq.com"
          "+.stun.*.*"
        ];

        default-nameserver = [
          "223.5.5.5"
          "119.29.29.29"
        ];
        nameserver = [
          "https://doh.pub/dns-query"
          "https://dns.alidns.com/dns-query"
        ];
        proxy-server-nameserver = [
          "https://doh.pub/dns-query"
          "https://dns.alidns.com/dns-query"
        ];
      }
      // lib.optionalAttrs isWork {
        nameserver-policy."+.${corpHosts.domain}" = "system";
      };

      sniffer = {
        enable = true;
        parse-pure-ip = true;
        override-destination = true;

        sniff = {
          HTTP = {
            ports = [
              "80"
              "8080-8880"
            ];
          };
          TLS = {
            ports = [
              "443"
              "8443"
            ];
          };
          QUIC = {
            ports = [
              "443"
              "8443"
            ];
          };
        };

        skip-domain = [
          "+.lan"
          "+.local"
          "+.push.apple.com"
        ];
      };
    };
in
{
  inherit
    mixedPort
    controllerPort
    stateDir
    ;

  mkOptions = {
    enable = lib.mkEnableOption "Mihomo proxy service";
    tun.enable = lib.mkEnableOption "TUN mode, which routes all host traffic through mihomo";
  };

  mkPackages =
    {
      pkgs,
      cfg,
      corpHosts,
      hostType,
      secretFile,
      subscriptionUrlFile,
    }:
    let
      inherit (pkgs.stdenv) isDarwin;

      isWork = hostType == "work";

      baseConfig = mkBaseConfig {
        inherit
          cfg
          corpHosts
          isWork
          isDarwin
          ;
      };

      updatePackage = mkNuCommand {
        inherit pkgs;
        name = "mihomo-update";
        script = ./update.nu;
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.mihomo
        ];

        config = {
          inherit
            baseConfig
            secretFile
            subscriptionUrlFile
            ;
          configDir = stateDir;
          inherit (proxy) proxyVars;

          curlArgs = [
            "-fsSL"

            "--connect-timeout"
            "10"

            "--max-time"
            "60"
          ];

          ruleProviders = lib.optionalAttrs isWork {
            Intranet = {
              type = "inline";
              behavior = "classical";
              payload = [
                "DOMAIN-SUFFIX,${corpHosts.domain}"
                "IP-CIDR,10.0.0.0/8,no-resolve"
              ];
            };
          };

          prependRules = lib.optionals isWork [
            "RULE-SET,Intranet,DIRECT"
          ];
        };
      };

      startPackage = mkNuCommand {
        inherit pkgs;
        name = "mihomo-start";
        script = ./start.nu;
        runtimeInputs = [
          pkgs.mihomo
          updatePackage
        ];
        flags.config-dir = stateDir;
      };

      checkPortPackage = mkNuCommand {
        inherit pkgs;
        name = "mihomo-check-port";
        script = ./check-port.nu;
        runtimeInputs = [ pkgs.iproute2 ];
        flags.port = toString mixedPort;
      };
    in
    {
      update = updatePackage;
      start = startPackage;

      # Go keeps an inherited SIG_IGN for SIGHUP until signal.Notify, so an early reload cannot kill
      # the start script or mihomo before mihomo handles it.
      startCommand = [
        (lib.getExe' pkgs.coreutils "env")
        "--ignore-signal=HUP"
        (lib.getExe startPackage)
      ];

      checkPort = lib.getExe checkPortPackage;
    };
}
