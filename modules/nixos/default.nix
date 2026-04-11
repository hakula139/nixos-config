# ==============================================================================
# NixOS Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  secrets,
  keys,
  ...
}:

let
  cfg = config.hakula;
  sshCfg = cfg.access.ssh;
  userCfg = config.users.users.${cfg.user.name};

  shared = import ../shared.nix { inherit pkgs lib; };
  mcpOptions = import ../../home/modules/llm-assistants/shared/mcp/options.nix { inherit lib; };
  proxyOptions = import ../../home/modules/llm-assistants/shared/proxy.nix { inherit lib; };
in
{
  imports = [
    ./aria2
    ./backup
    ./builders
    ./cachix
    ./clash
    ./claude-code
    ./cloudcone
    ./cloudreve
    ./clove
    ./dockerhub
    ./fuclaude
    ./mcp
    ./netdata
    ./nginx
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
  options.hakula.access.ssh.authorizedKeys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = lib.attrValues keys.users;
    description = "SSH public keys authorized for user login";
  };

  options.hakula.network.realitySniHost = lib.mkOption {
    type = lib.types.str;
    default = "www.microsoft.com";
    description = ''
      REALITY SNI host used for TLS camouflage in Xray and SNI-based routing in nginx.
      If you change this, also update secrets/shared/xray-config.json.age.
    '';
  };

  options.hakula.user.name = lib.mkOption {
    type = lib.types.str;
    default = "hakula";
    description = "Primary user account name";
  };

  options.hakula.llm-assistants = {
    enable = lib.mkEnableOption "LLM assistants for the primary interactive user";

    user = lib.mkOption {
      type = lib.types.str;
      default = cfg.user.name;
      description = "Home Manager user to receive assistant defaults";
    };

    mcp = {
      disabledServers = mcpOptions.mkDisabledServersOption {
        description = "MCP servers to disable across all LLM assistants";
      };
    };

    proxy = proxyOptions.mkProxyOptions "LLM assistants";
  };

  config = lib.mkMerge [
    {
      # ------------------------------------------------------------------------
      # Core System
      # ------------------------------------------------------------------------
      time.timeZone = "Asia/Shanghai";

      i18n = {
        defaultLocale = "en_US.UTF-8";
        supportedLocales = [ "en_US.UTF-8/UTF-8" ];
        extraLocaleSettings.LC_ALL = "en_US.UTF-8";
      };

      console.keyMap = "us";

      # ------------------------------------------------------------------------
      # Nix Configuration
      # ------------------------------------------------------------------------
      nix = {
        settings =
          shared.nixSettings
          // lib.optionalAttrs config.hakula.cachix.enable {
            inherit (shared.binaryCaches) substituters trusted-public-keys;
          };

        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 7d";
        };
        optimise.automatic = true;
      };

      nixpkgs.config.allowUnfree = true;

      # ------------------------------------------------------------------------
      # Boot & Kernel
      # ------------------------------------------------------------------------
      boot.kernel.sysctl = {
        # TCP BBR: Better throughput on high-latency / lossy networks
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
        # Memory: Reduce swap usage on memory-constrained servers
        "vm.swappiness" = 10;
        "vm.vfs_cache_pressure" = 50;
      };

      # ------------------------------------------------------------------------
      # Disk Optimization
      # ------------------------------------------------------------------------
      # Limit journal size to prevent excessive disk usage
      services.journald.extraConfig = ''
        SystemMaxUse=200M
        MaxRetentionSec=7day
      '';

      # ------------------------------------------------------------------------
      # Networking
      # ------------------------------------------------------------------------
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

      # ------------------------------------------------------------------------
      # Users & Security
      # ------------------------------------------------------------------------
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

      # ------------------------------------------------------------------------
      # Environment
      # ------------------------------------------------------------------------
      programs.zsh.enable = true;
      environment.shells = [ pkgs.zsh ];

      # /bin/bash symlink for scripts with #!/bin/bash shebangs
      system.activationScripts.binbash.text = ''
        mkdir -p /bin
        ln -sfn ${pkgs.bash}/bin/bash /bin/bash
      '';

      environment.variables = {
        LANG = "en_US.UTF-8";
        LC_ALL = "en_US.UTF-8";
      };

      # Nix-LD: Run unpatched Linux binaries
      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
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
        ];
      };

      # ------------------------------------------------------------------------
      # Fonts & Packages
      # ------------------------------------------------------------------------
      fonts = {
        packages = shared.fonts;
        fontconfig.enable = true;
      };
      environment.systemPackages = shared.basePackages;

      # ------------------------------------------------------------------------
      # Secrets Configuration (agenix)
      # ------------------------------------------------------------------------
      systemd.tmpfiles.rules = secrets.mkSecretsDir userCfg userCfg.group;
    }

    # --------------------------------------------------------------------------
    # LLM Assistants
    # --------------------------------------------------------------------------
    (lib.mkIf cfg.llm-assistants.enable {
      hakula.claude-code = {
        enable = lib.mkDefault true;
        auth = {
          method = lib.mkDefault "api-key";
          baseUrl = lib.mkDefault "https://co.yes.vg";
        };
      };
      hakula.mcp.enable = lib.mkDefault true;

      home-manager.users.${cfg.llm-assistants.user}.hakula = {
        llm-assistants = {
          enable = lib.mkDefault true;
          mcp.disabledServers = lib.mkDefault cfg.llm-assistants.mcp.disabledServers;
          proxy = lib.mkIf cfg.llm-assistants.proxy.enable {
            enable = lib.mkDefault true;
            url = lib.mkDefault cfg.llm-assistants.proxy.url;
            noProxy = lib.mkDefault cfg.llm-assistants.proxy.noProxy;
          };
        };

        claude-code.auth = {
          method = lib.mkOverride 900 config.hakula.claude-code.auth.method;
          baseUrl = lib.mkOverride 900 config.hakula.claude-code.auth.baseUrl;
        };
      };
    })
  ];
}
