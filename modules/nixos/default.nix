# ==================================================================================================
# NixOS Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  keys,
  isDesktop,
  repoLib,
  ...
}:

let
  cfg = config.hakula;
  sshCfg = cfg.access.ssh;
  userConfig = config.users.users.${cfg.user.name};

  packages = repoLib.packagesFor pkgs;
in
{
  imports = [
    ./aria2
    ./backup
    ./builders
    ./clash
    ./cloudreve
    ./earlyoom
    ./fhs-compat
    ./mihomo
    ./netdata
    ./nginx
    ./nix-daemon-proxy
    ./peertube
    ./podman
    ./postgresql
    ./ssh
    ./tailscale
    ./umami
    ./xray

    ../shared/base
    ../shared/cachix
    ../shared/llm-assistants
    ../shared/nix-caches
    ../shared/nix-gc
    ../shared/tailscale
    ../shared/user
    ../shared/user-secrets
  ];

  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.network = {
    internalHttpsSocket = lib.mkOption {
      type = lib.types.str;
      default = "/run/nginx/https.sock";
      readOnly = true;
      description = "Unix socket for nginx HTTPS";
    };

    internalRealitySocket = lib.mkOption {
      type = lib.types.str;
      default = "/run/xray/reality.sock";
      readOnly = true;
      description = "Unix socket for the Xray REALITY inbound";
    };

    internalWsSocket = lib.mkOption {
      type = lib.types.str;
      default = "/run/xray/ws.sock";
      readOnly = true;
      description = "Unix socket for the Xray WebSocket inbound";
    };

    realitySniHost = lib.mkOption {
      type = lib.types.str;
      default = "hakula.xyz";
      readOnly = true;
      description = ''
        REALITY SNI host used for TLS camouflage in Xray and SNI-based routing in nginx.
        Steal-oneself: this is our own domain, so Xray's REALITY `dest` borrows the local nginx
        certificate instead of a third-party site.
      '';
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = {
    # ----------------------------------------------------------------------------------------------
    # Core System
    # ----------------------------------------------------------------------------------------------
    i18n = {
      defaultLocale = "en_US.UTF-8";
      supportedLocales = [
        "en_US.UTF-8/UTF-8"
      ];
      extraLocaleSettings.LC_ALL = "en_US.UTF-8";
    };

    console.keyMap = "us";

    # ----------------------------------------------------------------------------------------------
    # Boot & Kernel
    # ----------------------------------------------------------------------------------------------
    boot.kernel.sysctl = {
      # TCP BBR: Better throughput on high-latency / lossy networks
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
      # Memory
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
    };

    # ----------------------------------------------------------------------------------------------
    # Disk Optimization
    # ----------------------------------------------------------------------------------------------
    services.journald.extraConfig = ''
      SystemMaxUse=500M
      MaxRetentionSec=14day
    '';

    # /tmp and /var/tmp age by ctime and mtime, and directories by birth time and mtime, since
    # read-only traversals (du, ripgrep, backup scans) renew atime. Replacing the stock tmp.conf
    # prevents a duplicate /tmp rule.
    environment.etc."tmpfiles.d/tmp.conf".text = ''
      q /tmp 1777 root root cmBM:3d
      q /var/tmp 1777 root root cmBM:10d
    '';

    # ----------------------------------------------------------------------------------------------
    # Networking
    # ----------------------------------------------------------------------------------------------
    networking = {
      domain = "hakula.xyz";

      firewall = {
        enable = true;
        allowPing = true;
        allowedTCPPorts = [
          80
          443
        ];
      };
    };

    # ----------------------------------------------------------------------------------------------
    # Users & Security
    # ----------------------------------------------------------------------------------------------
    hakula.user.group = userConfig.group;

    users.defaultUserShell = pkgs.zsh;

    users.users = lib.mkMerge [
      {
        root.openssh.authorizedKeys.keys = sshCfg.authorizedKeys ++ [ keys.builder ];
      }

      {
        # Root lingers too, so /run/user/<uid> exists for shells outside a login session, such as
        # docker exec. Home Manager's tmux secureSocket puts its socket there.
        ${cfg.user.name}.linger = true;
      }

      (lib.mkIf (cfg.user.name != "root") {
        ${cfg.user.name} = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
          ];
          openssh.authorizedKeys.keys = sshCfg.authorizedKeys;
        };
      })
    ];

    security.sudo.wheelNeedsPassword = false;

    # ----------------------------------------------------------------------------------------------
    # Systemd
    # ----------------------------------------------------------------------------------------------
    # logind starts a user manager once while the user stays tracked, and linger keeps the user
    # tracked, so only systemd can bring back a manager that dies.
    systemd.services."user@" = repoLib.systemd.restartUnit;

    # ----------------------------------------------------------------------------------------------
    # Shell & Environment
    # ----------------------------------------------------------------------------------------------
    environment.shells = [
      pkgs.zsh
    ];

    environment.variables = lib.optionalAttrs config.security.pki.installCACerts {
      # uv's Python builds use upstream OpenSSL paths instead of the NixOS CA bundle.
      SSL_CERT_FILE = lib.mkDefault "\${SSL_CERT_FILE-${config.security.pki.caBundle}}";
    };

    # Nix-LD: Run unpatched Linux binaries
    programs.nix-ld = {
      enable = true;
      libraries =
        with pkgs;
        [
          curl
          glib
          glibc
          icu
          libkrb5
          libsecret
          libunwind
          libuuid
          openssl
          stdenv.cc.cc.lib
          util-linux
          zlib
        ]
        # Project-local Playwright versions may still download their own Chromium. The managed
        # browser tools carry these libraries in their Nix closure.
        ++ [
          alsa-lib
          at-spi2-atk
          at-spi2-core
          atk
          cairo
          cups
          dbus
          expat
          fontconfig
          freetype
          gtk3
          libdrm
          libgbm
          libx11
          libxcb
          libxcomposite
          libxcursor
          libxdamage
          libxext
          libxfixes
          libxi
          libxkbcommon
          libxrandr
          libxrender
          libxscrnsaver
          libxtst
          mesa
          nspr
          nss
          pango
        ];
    };

    # ----------------------------------------------------------------------------------------------
    # Fonts
    # ----------------------------------------------------------------------------------------------
    fonts = lib.mkIf isDesktop {
      packages = packages.fonts;
      fontconfig.enable = true;
    };
  };
}
