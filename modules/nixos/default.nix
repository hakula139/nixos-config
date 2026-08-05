# ==============================================================================
# NixOS Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  secrets,
  keys,
  sharedConfig,
  ...
}:

let
  cfg = config.hakula;
  sshCfg = cfg.access.ssh;
  userConfig = config.users.users.${cfg.user.name};
  homeConfig = config.home-manager.users.${cfg.user.name} or { };

  shared = sharedConfig { inherit pkgs lib; };
in
{
  imports = [
    ./aria2
    ./backup
    ./builders
    ./cachix
    ./clash
    ./cloudcone
    ./cloudreve
    ./clove
    ./dockerhub
    ./fhs-compat
    ./fuclaude
    ./llm-assistants
    ./netdata
    ./nginx
    ./nix-daemon-proxy
    ./peertube
    ./piclist
    ./podman
    ./postgresql
    ./ssh
    ./umami
    ./xray
  ];

  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.access.ssh = {
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSH public keys authorized for user login";
    };
  };

  options.hakula.network = {
    realitySniHost = lib.mkOption {
      type = lib.types.str;
      default = "hakula.xyz";
      description = ''
        REALITY SNI host used for TLS camouflage in Xray and SNI-based routing in nginx.
        Steal-oneself: this is our own domain, so Xray's REALITY `dest` borrows the
        local nginx cert (127.0.0.1:8443) instead of a third-party site. Keep this in
        sync with `serverNames` in secrets/xray/config.json.age, and keep `dest` there
        pointed at the local nginx HTTPS port.
      '';
    };
  };

  options.hakula.user.name = lib.mkOption {
    type = lib.types.str;
    default = "hakula";
    description = "Primary user account name";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = {
    # --------------------------------------------------------------------------
    # Core System
    # --------------------------------------------------------------------------
    time.timeZone = "Asia/Shanghai";

    i18n = {
      defaultLocale = "en_US.UTF-8";
      supportedLocales = [ "en_US.UTF-8/UTF-8" ];
      extraLocaleSettings.LC_ALL = "en_US.UTF-8";
    };

    console.keyMap = "us";

    # --------------------------------------------------------------------------
    # Nix Configuration
    # --------------------------------------------------------------------------
    nix = {
      settings =
        shared.nixSettings
        // lib.optionalAttrs config.hakula.cachix.enable {
          inherit (shared.binaryCaches) substituters trusted-public-keys;
        };

      gc = {
        automatic = true;
        dates = "daily";
        options = "--delete-older-than 7d";
      };
      optimise.automatic = true;
    };

    nixpkgs.config.allowUnfree = true;

    # --------------------------------------------------------------------------
    # Boot & Kernel
    # --------------------------------------------------------------------------
    boot.kernel.sysctl = {
      # TCP BBR: Better throughput on high-latency / lossy networks
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
      # Memory: Reduce swap usage on memory-constrained servers
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
    };

    # --------------------------------------------------------------------------
    # Disk Optimization
    # --------------------------------------------------------------------------
    # Limit journal size to prevent excessive disk usage
    services.journald.extraConfig = ''
      SystemMaxUse=200M
      MaxRetentionSec=7day
    '';

    # The daily tmpfiles aging of /tmp ages by atime, so any read-only traversal
    # (du, ripgrep, a backup scan) defers deletion by another 10 days. Wiping at
    # boot bounds /tmp regardless.
    boot.tmp.cleanOnBoot = true;

    # --------------------------------------------------------------------------
    # Networking
    # --------------------------------------------------------------------------
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

    # --------------------------------------------------------------------------
    # Users & Security
    # --------------------------------------------------------------------------
    users.defaultUserShell = pkgs.zsh;

    users.users = {
      root.openssh.authorizedKeys.keys = sshCfg.authorizedKeys ++ [ keys.builder ];
    }
    // lib.optionalAttrs (cfg.user.name != "root") {
      ${cfg.user.name} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = sshCfg.authorizedKeys;
        linger = true;
      };
    };

    security.sudo.wheelNeedsPassword = false;

    # --------------------------------------------------------------------------
    # Shell & Environment
    # --------------------------------------------------------------------------
    programs.zsh.enable = true;
    environment.shells = [ pkgs.zsh ];
    environment.variables = shared.localeSettings;

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
        # Shared libraries for Playwright's downloaded Chromium (Fetcher MCP),
        # which links against a full desktop stack absent from a headless NixOS.
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

    # --------------------------------------------------------------------------
    # Fonts & Packages
    # --------------------------------------------------------------------------
    fonts = {
      packages = shared.fonts;
      fontconfig.enable = true;
    };
    environment.systemPackages = shared.basePackages;

    # --------------------------------------------------------------------------
    # Secrets Configuration (agenix)
    # --------------------------------------------------------------------------
    age.secrets = secrets.mkRequiredUserSecrets {
      inherit homeConfig userConfig;
    };
  };
}
