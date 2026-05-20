# ==============================================================================
# System Manager Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  secrets,
  keys,
  sharedConfig,
  systemManagerLib,
  ...
}:

let
  cfg = config.hakula;
  homeConfig = config.home-manager.users.${cfg.user.name};
  sshCfg = cfg.access.ssh;
  userConfig = config.users.users.${cfg.user.name};

  shared = sharedConfig { inherit pkgs lib; };
  systemManagerHealthCheck = pkgs.writeShellScriptBin "system-manager-health-check" (
    builtins.readFile ./health-check.sh
  );
in
{
  imports = [
    ./age.nix
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

  options.hakula.user.name = lib.mkOption {
    type = lib.types.str;
    default = "hakula";
    description = "Primary user account name";
  };

  options.programs.zsh = {
    enable = lib.mkEnableOption "zsh shell integration";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = {
    # --------------------------------------------------------------------------
    # Users
    # --------------------------------------------------------------------------
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

    # --------------------------------------------------------------------------
    # Nix Configuration
    # --------------------------------------------------------------------------
    nix = {
      enable = true;
      settings = shared.nixSettings // {
        trusted-users = [
          "root"
          cfg.user.name
        ];
      };
    };

    # --------------------------------------------------------------------------
    # Environment
    # --------------------------------------------------------------------------
    environment.variables = {
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
    };

    environment.systemPackages = shared.basePackages ++ [
      systemManagerHealthCheck
      pkgs.system-manager
      pkgs.zsh
    ];

    programs.zsh.enable = true;

    # Nix-built zsh reads /etc/zprofile for login shells; system-manager uses it
    # to expose the configured system PATH.
    environment.etc.zprofile = lib.mkIf config.programs.zsh.enable {
      text = ''
        typeset -U path PATH
        path=(${lib.concatMapStringsSep " " (p: ''"${p}"'') systemManagerLib.systemPaths} $path)
      '';
    };

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.identityPaths = [ "${userConfig.home}/.ssh/id_ed25519" ];

    age.secrets = secrets.mkRequiredUserSecrets {
      inherit homeConfig userConfig;
    };

    systemd.services."home-manager-${cfg.user.name}" = lib.mkIf (config.age.secrets != { }) {
      after = [ "agenix-install-secrets.service" ];
      requires = [ "agenix-install-secrets.service" ];
    };
  };
}
