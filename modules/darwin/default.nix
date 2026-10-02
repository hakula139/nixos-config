# ==============================================================================
# Darwin (macOS) Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  caches,
  defaults,
  keys,
  repoLib,
  servers,
  ...
}:

let
  packages = repoLib.packagesFor pkgs;
  userName = config.hakula.user.name;
  homeConfig = config.home-manager.users.${userName} or { };
  userConfig = {
    name = userName;
    home = config.users.users.${userName}.home or "/Users/${userName}";
  };
  sshCfg = config.hakula.access.ssh;
  serverList = lib.attrValues servers;
in
{
  imports = [
    ./corp-tunnel
    ./homebrew.nix
    ./keka
    ./llm-assistants
    ./ssh
    ./system.nix
    ./tailscale
  ];

  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.access.ssh = {
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lib.attrValues keys.workstations;
      description = "SSH public keys authorized for user login";
    };
  };

  options.hakula.cachix = {
    enable = lib.mkEnableOption "Cachix auth token secret";
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
    # Secrets
    # --------------------------------------------------------------------------
    age.identityPaths = [ "${userConfig.home}/.ssh/id_ed25519" ];

    age.secrets = {
      builder-ssh-key = repoLib.secrets.mkSecret {
        name = "builders/ssh-key";
        owner = userName;
        group = "staff";
      };
    }
    // repoLib.secrets.mkRequiredUserSecrets {
      inherit homeConfig userConfig;
      group = "staff";
    };

    # --------------------------------------------------------------------------
    # Nix Configuration
    # --------------------------------------------------------------------------
    nix = {
      enable = true;

      settings =
        defaults.nixSettings
        // {
          extra-trusted-users = [ "hakula" ];
          builders-use-substitutes = true;
        }
        // lib.optionalAttrs config.hakula.cachix.enable {
          inherit (caches) substituters trusted-public-keys;
        };

      distributedBuilds = true;
      buildMachines = repoLib.ssh.mkBuildMachines serverList config.age.secrets.builder-ssh-key.path;

      gc = {
        automatic = true;
        interval = {
          Weekday = 0; # Sunday
          Hour = 2;
          Minute = 0;
        };
        options = "--delete-older-than 7d";
      };
      optimise.automatic = true;
    };

    nixpkgs.config.allowUnfree = true;

    # --------------------------------------------------------------------------
    # Environment
    # --------------------------------------------------------------------------
    launchd.user.envVariables.PATH = [
      "${userConfig.home}/.nix-profile/bin"
      "/etc/profiles/per-user/${userName}/bin"
      "/run/current-system/sw/bin"
      "/nix/var/nix/profiles/default/bin"
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
      "/usr/local/bin"
      "/usr/bin"
      "/bin"
      "/usr/sbin"
      "/sbin"
    ];

    # --------------------------------------------------------------------------
    # Users & Security
    # --------------------------------------------------------------------------
    users.users.hakula = {
      name = "hakula";
      home = "/Users/hakula";
      openssh.authorizedKeys.keys = sshCfg.authorizedKeys;
    };

    system.primaryUser = "hakula";

    security.pam.services.sudo_local = {
      touchIdAuth = true;
      reattach = true;
    };

    # Network → Firewall
    networking.applicationFirewall = {
      enable = true;
      enableStealthMode = true;
      allowSigned = false;
      allowSignedApp = false;
    };

    # --------------------------------------------------------------------------
    # SSH Configuration (system-wide)
    # --------------------------------------------------------------------------
    programs.ssh.extraConfig = repoLib.ssh.mkExtraConfig serverList config.age.secrets.builder-ssh-key.path;

    programs.ssh.knownHosts = repoLib.ssh.mkKnownHosts serverList;

    # --------------------------------------------------------------------------
    # Shell & Environment
    # --------------------------------------------------------------------------
    programs.zsh.enable = true;
    environment.shells = [ pkgs.zsh ];
    environment.variables = defaults.localeSettings;

    # --------------------------------------------------------------------------
    # Fonts & Packages
    # --------------------------------------------------------------------------
    fonts.packages = packages.fonts;
    environment.systemPackages = packages.base ++ [ pkgs.thaw ];

  };
}
