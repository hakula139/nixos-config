# ==============================================================================
# hakula-linux System Manager Configuration
# ==============================================================================

{
  config,
  lib,
  corpDomain,
  ...
}:

let
  userName = config.hakula.user.name;
  userConfig = config.users.users.${userName};
in
{
  # ----------------------------------------------------------------------------
  # Home Manager Settings
  # ----------------------------------------------------------------------------
  home-manager.users.${userName} = {
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
    hakula.secrets.required = {
      github-pat.name = lib.mkForce "github/pat-work";

      wakatime-config = {
        name = "wakatime/config";
        path = "${userConfig.home}/.wakatime.cfg";
      };
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
}
