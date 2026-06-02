# ==============================================================================
# WSL Workstation Bundle
# ==============================================================================

{
  config,
  lib,
  options,
  corpDomain,
  ...
}:

let
  cfg = config.hakula.wsl;
  gitlabWorkHost = "gitlab-general.${corpDomain}";
  gitlabLegacyHost = "gitlab-public.${corpDomain}";
  gitlabSshBlock = {
    host = lib.mkDefault gitlabWorkHost;
    hostname = lib.mkDefault gitlabWorkHost;
    user = lib.mkDefault "git";
    port = lib.mkDefault 8022;
  };
  gitlabLegacySshBlock = gitlabSshBlock // {
    host = lib.mkDefault gitlabLegacyHost;
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.wsl = {
    enable = lib.mkEnableOption "Hakula's WSL workstation Home Manager bundle";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    # --------------------------------------------------------------------------
    # Home Manager Overrides
    # --------------------------------------------------------------------------
    hakula.claude-code.auth = {
      defaultProfile = "corp-gateway-bedrock";
      enableCorpGateway = true;
    };

    hakula.cursor.extensions.prune = lib.mkForce false;

    hakula.fonts.windowsSync.enable = lib.mkDefault true;

    hakula.llm-assistants = {
      enable = lib.mkDefault true;
      proxy.noProxy = lib.mkDefault [
        "localhost"
        "127.0.0.1"
        "10.*"
        ".${corpDomain}"
      ];
    };

    hakula.mihomo = {
      enable = lib.mkDefault false;
      port = lib.mkDefault 7897;
      controllerPort = lib.mkDefault 59386;
    };

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    hakula.secrets.required.github-pat.name = lib.mkForce "github/pat-work";

    # --------------------------------------------------------------------------
    # SSH Configuration
    # --------------------------------------------------------------------------
    programs.ssh =
      if builtins.hasAttr "settings" options.programs.ssh then
        {
          settings = {
            ${gitlabWorkHost} = {
              HostName = gitlabSshBlock.hostname;
              User = gitlabSshBlock.user;
              Port = gitlabSshBlock.port;
            };
            ${gitlabLegacyHost} = {
              HostName = gitlabSshBlock.hostname;
              User = gitlabSshBlock.user;
              Port = gitlabSshBlock.port;
            };
          };
        }
      else
        {
          matchBlocks = {
            ${gitlabWorkHost} = gitlabSshBlock;
            ${gitlabLegacyHost} = gitlabLegacySshBlock;
          };
        };
  };
}
