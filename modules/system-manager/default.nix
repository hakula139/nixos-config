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
  homeConfig = config.home-manager.users.${cfg.user.name};
  sshCfg = cfg.access.ssh;
  userConfig = config.users.users.${cfg.user.name};

  shared = sharedConfig { inherit pkgs lib; };
  systemManagerHealthCheck = pkgs.writeShellScriptBin "system-manager-health-check" ''
    set -euo pipefail

    if [ "$#" -eq 0 ]; then
      echo "usage: system-manager-health-check <service>..." >&2
      exit 2
    fi

    rc=0
    for service in "$@"; do
      if ! systemctl list-unit-files "$service" >/dev/null 2>&1; then
        echo "service '$service' is not installed; skipping" >&2
        continue
      fi
      if ! systemctl is-active --quiet "$service"; then
        echo "service '$service' is not active" >&2
        # `systemctl status` exits non-zero on failed units by design, so suppress that.
        systemctl status --no-pager "$service" >&2 || true
        rc=1
      fi
    done
    exit "$rc"
  '';
in
{
  imports = [
    ./age.nix
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
    # Nix
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

    # Nix-built zsh's compile-time global rcs are /etc/zprofile (login),
    # /etc/zshrc (interactive), and a store-bundled zshenv. Write /etc/zprofile
    # so login zsh, including tmux panes and ssh sessions, sees system PATH.
    environment.etc.zprofile = lib.mkIf config.programs.zsh.enable {
      text = ''
        typeset -U path PATH
        path=(
          "/run/wrappers/bin"
          "/etc/profiles/per-user/$USER/bin"
          "/run/system-manager/sw/bin"
          $path
        )
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
