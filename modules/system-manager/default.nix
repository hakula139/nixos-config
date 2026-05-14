# ==============================================================================
# System Manager Configuration
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
  userCfg = config.users.users.${cfg.user.name};
  sshCfg = cfg.access.ssh;

  shared = import ../shared.nix { inherit pkgs lib; };
in
{
  imports = [
    ./age.nix
    ../nixos/llm-assistants
  ];

  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.access.ssh.authorizedKeys = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = lib.attrValues keys.workstations;
    description = "SSH public keys authorized for user login";
  };

  options.hakula.user.name = lib.mkOption {
    type = lib.types.str;
    default = "hakula";
    description = "Primary user account name";
  };

  options.programs.zsh.enable = lib.mkEnableOption "zsh shell integration";

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
    # Environment
    # --------------------------------------------------------------------------
    environment.variables = {
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
    };

    environment.systemPackages = shared.basePackages ++ [
      pkgs.zsh
    ];

    programs.zsh.enable = true;

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.identityPaths = [ "${userCfg.home}/.ssh/id_ed25519" ];
    systemd.tmpfiles.rules = secrets.mkSecretsDir userCfg userCfg.group;

    systemd.services."home-manager-${cfg.user.name}" = lib.mkIf (config.age.secrets != { }) {
      after = [ "agenix-install-secrets.service" ];
      requires = [ "agenix-install-secrets.service" ];
    };
  };
}
