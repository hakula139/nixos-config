# ==================================================================================================
# T3 Code Configuration
# ==================================================================================================

{
  config,
  lib,
  inputs,
  isDesktop,
  secretPath,
  ...
}:

let
  cfg = config.hakula.t3code;
  enableCorpGateway = config.hakula.llm-assistants.auth.enableCorpGateway;
  corpGateway = config.lib.llmAssistants.profileDefinitions.providers.corp-gateway;
in
{
  imports = [
    inputs.agents-nix.homeModules.t3code
  ];

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
    hakula.secrets.required = lib.optionalAttrs enableCorpGateway {
      ${corpGateway.caSecret} = { };
    };

    agents.t3code = {
      enable = true;
      headless = !isDesktop;
      inherit (cfg) lan;
      caCertFile = lib.mkIf enableCorpGateway (secretPath corpGateway.caSecret);
      service.launchdLabel = "com.hakula.t3code";
    };
  };
}
