# ==============================================================================
# WSL Workstation Bundle
# ==============================================================================

{
  config,
  lib,
  corpDomain,
  ...
}:

let
  cfg = config.hakula.wsl;
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

    hakula.cursor = {
      extensions.prune = lib.mkForce false;
      windowsSettings = {
        "debug.console.fontSize" = lib.mkDefault 13;
        "editor.fontSize" = lib.mkDefault 15;
        "terminal.integrated.fontSize" = lib.mkDefault 13;
        "window.zoomLevel" = lib.mkDefault 1;
      };
      windowsSync.enable = lib.mkDefault true;
    };

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
  };
}
