# ==================================================================================================
# T3 Code Configuration
# ==================================================================================================

{
  config,
  lib,
  isDesktop,
  ...
}:

let
  cfg = config.hakula.t3code;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.t3code = {
    enable = lib.mkEnableOption "T3 Code";
    lan = lib.mkEnableOption "serving the LAN and tailnet";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf (config.hakula.llm-assistants.enable && cfg.enable) {
    agents.t3code = {
      enable = true;
      headless = !isDesktop;
      inherit (cfg) lan;
      service.launchdLabel = "com.hakula.t3code";
    };
  };
}
