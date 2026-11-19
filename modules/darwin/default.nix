# ==================================================================================================
# Darwin (macOS) Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  servers,
  ...
}:

let
  packages = repoLib.packagesFor pkgs;
  userName = config.hakula.user.name;
  userHome = "/Users/${userName}";

  sshCfg = config.hakula.access.ssh;
  serverList = lib.attrValues servers;
  builderKeyPath = config.age.secrets.builder-ssh-key.path;
in
{
  imports = [
    ./homebrew.nix
    ./system.nix

    ./aria2
    ./betterdisplay
    ./drivedx
    ./keka
    ./mihomo
    ./nh-clean
    ./ssh
    ./tailscale
    ./tunnel

    ../shared/base
    ../shared/cachix
    ../shared/llm-assistants
    ../shared/nix-caches
    ../shared/user
    ../shared/user-secrets
  ];

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = {
    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    age.identityPaths = [ "${userHome}/.ssh/id_ed25519" ];

    age.secrets.builder-ssh-key = repoLib.secrets.mkDarwinUserSecret userName {
      name = "builders/ssh-key";
    };

    # ----------------------------------------------------------------------------------------------
    # Nix Configuration
    # ----------------------------------------------------------------------------------------------
    nix = {
      enable = true;

      settings = {
        extra-trusted-users = [
          userName
        ];
        builders-use-substitutes = true;
      };

      distributedBuilds = true;
      buildMachines = repoLib.ssh.mkBuildMachines serverList builderKeyPath;
    };

    # ----------------------------------------------------------------------------------------------
    # Environment
    # ----------------------------------------------------------------------------------------------
    launchd.user.envVariables.PATH = [
      "${userHome}/.nix-profile/bin"
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

    # ----------------------------------------------------------------------------------------------
    # Users & Security
    # ----------------------------------------------------------------------------------------------
    hakula.user.group = "staff";

    users.users.${userName} = {
      name = userName;
      home = userHome;
      openssh.authorizedKeys.keys = sshCfg.authorizedKeys;
    };

    system.primaryUser = userName;

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

    # ----------------------------------------------------------------------------------------------
    # SSH Configuration (system-wide)
    # ----------------------------------------------------------------------------------------------
    programs.ssh = {
      extraConfig = repoLib.ssh.mkExtraConfig serverList builderKeyPath;
      knownHosts = repoLib.ssh.mkKnownHosts serverList;
    };

    # ----------------------------------------------------------------------------------------------
    # Shell & Environment
    # ----------------------------------------------------------------------------------------------
    environment.shells = [
      pkgs.zsh
    ];

    # ----------------------------------------------------------------------------------------------
    # Fonts & Packages
    # ----------------------------------------------------------------------------------------------
    fonts.packages = packages.fonts;
    environment.systemPackages = [
      pkgs.thaw
    ];
  };
}
