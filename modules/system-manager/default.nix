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
  ...
}:

let
  cfg = config.hakula;
  userConfig = config.users.users.${cfg.user.name};
  homeConfig = config.home-manager.users.${cfg.user.name};
  sshCfg = cfg.access.ssh;

  shared = sharedConfig { inherit pkgs lib; };
  systemManagerHealthCheck = pkgs.writeShellScriptBin "system-manager-health-check" ''
    set -euo pipefail

    for service in "$@"; do
      if ! systemctl is-active --quiet "$service"; then
        systemctl status --no-pager "$service" >&2 || true
        exit 1
      fi
    done
  '';
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
    nix = {
      enable = true;
      settings = shared.nixSettings // {
        trusted-users = [
          "root"
          cfg.user.name
        ];
      };
    };

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

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets = secrets.mkRequiredUserSecrets {
      inherit homeConfig userConfig;
    };

    age.identityPaths = [ "${userConfig.home}/.ssh/id_ed25519" ];
    systemd.tmpfiles.rules = secrets.mkSecretsDir userConfig userConfig.group;

    systemd.services."home-manager-${cfg.user.name}" = lib.mkIf (config.age.secrets != { }) {
      after = [ "agenix-install-secrets.service" ];
      requires = [ "agenix-install-secrets.service" ];
    };
  };
}
