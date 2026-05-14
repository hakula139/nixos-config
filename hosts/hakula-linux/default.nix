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
in
{
  # ----------------------------------------------------------------------------
  # Home Manager Settings
  # ----------------------------------------------------------------------------
  home-manager.users.${userName} = {
    home.stateVersion = "25.05";

    hakula.claude-code.auth = {
      defaultProfile = "corp-gateway";
      enableCorpGateway = true;
    };

    hakula.cursor.extensions = {
      enable = lib.mkForce true;
      prune = lib.mkForce false;
    };

    hakula.fonts.windowsSync.enable = true;

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

    hakula.mihomo = {
      enable = true;
      port = 7897;
      controllerPort = 59386;
    };

    hakula.secrets.required = {
      github-pat = {
        name = lib.mkForce "github/pat-work";
      };
    };

    programs.ssh.matchBlocks."gitlab-public.${corpDomain}" = {
      host = "gitlab-public.${corpDomain}";
      hostname = "gitlab-public.${corpDomain}";
      user = "git";
      port = 8022;
    };
  };
}
