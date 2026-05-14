# ==============================================================================
# MCP (Model Context Protocol)
# ==============================================================================

{
  config,
  lib,
  secrets,
  ...
}:

let
  cfg = config.hakula.mcp;
  userCfg = config.users.users.${cfg.user};
  assistantSecrets = import ../../../../lib/llm-assistants/secrets.nix {
    inherit secrets;
    homeDir = userCfg.home;
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.mcp = {
    enable = lib.mkEnableOption "MCP secrets";

    user = lib.mkOption {
      type = lib.types.str;
      default = config.hakula.llm-assistants.user;
      description = "User to store MCP secrets for";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasAttr cfg.user config.users.users;
        message = "hakula.mcp.user (${cfg.user}) must exist in config.users.users.*";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    age.secrets = secrets.mkUserSecretsFromSpecs {
      specs = assistantSecrets.mcp;
      user = userCfg;
    };
  };
}
