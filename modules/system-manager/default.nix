# ==================================================================================================
# System Manager Configuration
# ==================================================================================================

{
  nixosModulesPath,
  config,
  pkgs,
  lib,
  systemManagerPaths,
  ...
}:

let
  cfg = config.hakula;
  sshCfg = cfg.access.ssh;
  userConfig = config.users.users.${cfg.user.name};

  systemManagerHealthCheck = pkgs.writers.writeNuBin "system-manager-health-check" (
    builtins.readFile ./scripts/health-check.nu
  );
in
{
  imports = [
    ./sops.nix

    ../shared/base
    ../shared/cachix
    ../shared/llm-assistants
    ../shared/nix-caches
    ../shared/nix-gc
    ../shared/user
    ../shared/user-secrets
  ]
  ++ map (path: nixosModulesPath + path) [
    "/programs/nh.nix"
    "/services/misc/nix-gc.nix"
    "/services/misc/nix-optimise.nix"
  ];

  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.programs.zsh = {
    enable = lib.mkEnableOption "zsh shell integration";
  };

  options.time.timeZone = lib.mkOption {
    type = lib.types.str;
    description = "Time zone, applied through /etc/localtime";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = {
    # ----------------------------------------------------------------------------------------------
    # Users
    # ----------------------------------------------------------------------------------------------
    hakula.user.group = cfg.user.name;

    users.groups = {
      keys = { };
      ${cfg.user.name}.gid = lib.mkDefault 1000;
    };

    users.users.${cfg.user.name} = {
      isNormalUser = true;
      uid = lib.mkDefault 1000;
      group = cfg.user.name;
      home = lib.mkDefault "/home/${cfg.user.name}";
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = sshCfg.authorizedKeys;
    };

    # ----------------------------------------------------------------------------------------------
    # Nix Configuration
    # ----------------------------------------------------------------------------------------------
    nix.enable = true;

    # System Manager restarts changed units even when inactive, and upstream nh.nix leaves this on.
    systemd.services.nh-clean.restartIfChanged = false;

    # ----------------------------------------------------------------------------------------------
    # Shell & Environment
    # ----------------------------------------------------------------------------------------------
    environment.etc.localtime = {
      source = "${pkgs.tzdata}/share/zoneinfo/${config.time.timeZone}";
      replaceExisting = true;
    };

    # Nix-built zsh reads /etc/zprofile for login shells, the only hook system-manager has for
    # injecting the system PATH.
    environment.etc.zprofile = lib.mkIf config.programs.zsh.enable {
      text = ''
        typeset -U path PATH
        path=(${lib.concatMapStringsSep " " (p: ''"${p}"'') systemManagerPaths} $path)
      '';
    };

    # ----------------------------------------------------------------------------------------------
    # Packages
    # ----------------------------------------------------------------------------------------------
    environment.systemPackages = [
      systemManagerHealthCheck
      pkgs.system-manager
      pkgs.zsh
    ];

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    sops.age.sshKeyPaths = [ "${userConfig.home}/.ssh/id_ed25519" ];

    systemd.services."home-manager-${cfg.user.name}" = lib.mkIf (config.sops.secrets != { }) {
      after = [
        "sops-install-secrets.service"
      ];
      requires = [
        "sops-install-secrets.service"
      ];
    };
  };
}
