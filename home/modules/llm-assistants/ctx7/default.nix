# ==============================================================================
# Context7 Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  secretPath,
  ...
}:

let
  cfg = config.hakula.ctx7;
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.ctx7 = {
    enable = lib.mkEnableOption "Context7 CLI and documentation skill";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    hakula.secrets.required."llm-assistants/mcp/context7-api-key" = { };

    home.packages = [
      (repoLib.wrapPackage {
        inherit pkgs;
        pkg = pkgs.unstable.ctx7;
        envFiles.CONTEXT7_API_KEY = secretPath "llm-assistants/mcp/context7-api-key";
      })
    ];
  };
}
