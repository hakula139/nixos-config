# ==============================================================================
# hakula-linux System Manager Configuration
# ==============================================================================

{
  config,
  lib,
  secrets,
  ...
}:

let
  corpDomain = import ../../lib/corp-domain.nix;

  user = config.hakula.user.name;
  userCfg = config.users.users.${user};

  workstationSecrets = secrets.mkUserSecrets {
    names = [
      "wakatime/config"
    ];
    user = userCfg;
    overrides.wakatime-config.path = "${userCfg.home}/.wakatime.cfg";
  };
in
{
  # ----------------------------------------------------------------------------
  # Home Manager Settings
  # ----------------------------------------------------------------------------
  home-manager.users.${user} = {
    home.stateVersion = "25.05";

    hakula.claude-code.auth.enableCorpGateway = true;
    hakula.cursor.extensions = {
      enable = lib.mkForce true;
      prune = lib.mkForce false;
    };
    hakula.fonts.windowsSync.enable = true;
    hakula.mihomo = {
      enable = true;
      port = 7897;
      controllerPort = 59386;
    };

    programs.ssh.matchBlocks."gitlab-public.${corpDomain}" = {
      host = "gitlab-public.${corpDomain}";
      hostname = "gitlab-public.${corpDomain}";
      user = "git";
      port = 8022;
    };
  };

  # ----------------------------------------------------------------------------
  # Assistant Tooling
  # ----------------------------------------------------------------------------
  hakula.llm-assistants = {
    enable = true;
    proxy = {
      enable = true;
      noProxy = [
        "localhost"
        "127.0.0.1"
        "10.*"
        ".${corpDomain}"
      ];
    };
  };

  hakula.claude-code.defaultProfile = "corp-gateway";

  # ----------------------------------------------------------------------------
  # Workstation Secrets
  # ----------------------------------------------------------------------------
  age.secrets = workstationSecrets // {
    github-pat.file = lib.mkForce (secrets.secretFile "github/pat-work");
  };
}
