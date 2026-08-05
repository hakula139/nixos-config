# ==============================================================================
# WSL Workstation Bundle
# ==============================================================================

{
  config,
  lib,
  corpHosts,
  ...
}:

let
  inherit (corpHosts) wildcardDomain;

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
    hakula.claude-code.auth.defaultProfile = "corp-gateway-bedrock";

    hakula.cursor = {
      extensions.prune = lib.mkForce false;
      windowsSync.enable = lib.mkDefault true;
    };

    hakula.fonts.windowsSync.enable = lib.mkDefault true;

    hakula.llm-assistants = {
      enable = lib.mkDefault true;
      proxy.noProxy = lib.mkDefault [ wildcardDomain ];
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
