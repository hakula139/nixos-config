# ==================================================================================================
# Mihomo Settings
# ==================================================================================================

{
  lib,
  mkNuCommand,
  proxy,
}:

let
  # ------------------------------------------------------------------------------------------------
  # Paths and ports
  # ------------------------------------------------------------------------------------------------
  mixedPort = 7897;
  controllerPort = 59386;
  stateDir = "/var/lib/mihomo";

  # ------------------------------------------------------------------------------------------------
  # Base config
  # ------------------------------------------------------------------------------------------------
  mkBaseConfig =
    {
      cfg,
      corpHosts,
      isWork,
    }:
    let
      localDomains = [
        "*"
        "+.lan"
        "+.local"
        "+.arpa"
      ];
    in
    {
      # --------------------------------------------------------------------------------------------
      # Proxy ports
      # --------------------------------------------------------------------------------------------
      mixed-port = mixedPort;

      # --------------------------------------------------------------------------------------------
      # External control
      # --------------------------------------------------------------------------------------------
      external-controller = "127.0.0.1:${toString controllerPort}";

      # --------------------------------------------------------------------------------------------
      # Allow LAN
      # --------------------------------------------------------------------------------------------
      allow-lan = false;

      # --------------------------------------------------------------------------------------------
      # General
      # --------------------------------------------------------------------------------------------
      mode = "rule";
      log-level = "warning";
      ipv6 = true;
      unified-delay = true;
      tcp-concurrent = true;

      # --------------------------------------------------------------------------------------------
      # Auto update GEO
      # --------------------------------------------------------------------------------------------
      geo-auto-update = true;
      geo-update-interval = 24;

      # --------------------------------------------------------------------------------------------
      # Cache
      # --------------------------------------------------------------------------------------------
      profile = {
        store-selected = true;
        store-fake-ip = true;
      };

      # --------------------------------------------------------------------------------------------
      # TUN
      # --------------------------------------------------------------------------------------------
      tun = {
        enable = cfg.tun.enable;
        stack = "gvisor";
        auto-route = true;
        auto-detect-interface = true;
        mtu = 1500;
        dns-hijack = [
          "any:53"
          "tcp://any:53"
        ];
      };

      # --------------------------------------------------------------------------------------------
      # DNS
      # --------------------------------------------------------------------------------------------
      dns = {
        # ------------------------------------------------------------------------------------------
        # Basics
        # ------------------------------------------------------------------------------------------
        enable = true;
        ipv6 = true;
        use-system-hosts = true;

        # ------------------------------------------------------------------------------------------
        # Fake IP
        # ------------------------------------------------------------------------------------------
        enhanced-mode = "fake-ip";
        fake-ip-range = "198.18.0.1/16";
        fake-ip-range6 = "2001:2::/64";
        fake-ip-filter-mode = "blacklist";
        fake-ip-filter = localDomains ++ [
          "ntp.*.com"
          "time.*.com"
          "+.pool.ntp.org"

          "+.stun.*.*"

          "+.msftconnecttest.com"
          "+.msftncsi.com"

          "localhost.ptlogin2.qq.com"
        ];

        # ------------------------------------------------------------------------------------------
        # Upstreams
        # ------------------------------------------------------------------------------------------
        default-nameserver = [
          "223.5.5.5"
          "119.29.29.29"
        ];
        nameserver = [
          "https://dns.google/dns-query#RULES"
          "https://cloudflare-dns.com/dns-query#RULES"
        ];
        proxy-server-nameserver = [
          "https://doh.pub/dns-query"
          "https://dns.alidns.com/dns-query"
        ];

        nameserver-policy =
          lib.genAttrs localDomains (_: "system")
          // lib.optionalAttrs isWork {
            "+.${corpHosts.domain}" = "system";
          };
      };

      # --------------------------------------------------------------------------------------------
      # Sniffer
      # --------------------------------------------------------------------------------------------
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

  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  mkOptions = {
    enable = lib.mkEnableOption "Mihomo proxy service";
    tun.enable = lib.mkEnableOption "TUN mode, which routes all host traffic through mihomo";
  };

  # ------------------------------------------------------------------------------------------------
  # Packages
  # ------------------------------------------------------------------------------------------------
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
      isWork = hostType == "work";

      # --------------------------------------------------------------------------------------------
      # Base config
      # --------------------------------------------------------------------------------------------
      baseConfig = mkBaseConfig {
        inherit
          cfg
          corpHosts
          isWork
          ;
      };

      # --------------------------------------------------------------------------------------------
      # Update command
      # --------------------------------------------------------------------------------------------
      updatePackage = mkNuCommand {
        inherit pkgs;
        name = "mihomo-update";
        script = ./update.nu;
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.unstable.mihomo
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

      # --------------------------------------------------------------------------------------------
      # Service scripts
      # --------------------------------------------------------------------------------------------
      startPackage = mkNuCommand {
        inherit pkgs;
        name = "mihomo-start";
        script = ./start.nu;
        runtimeInputs = [
          pkgs.unstable.mihomo
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
