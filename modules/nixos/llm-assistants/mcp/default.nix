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
    age.secrets = secrets.mkUserSecrets {
      names = [
        "llm-assistants/mcp/confluence-pat"
        "llm-assistants/mcp/brave-api-key"
        "llm-assistants/mcp/context7-api-key"
        "github/pat-personal"
      ];
      user = userCfg;
      rename =
        name:
        if name == "github/pat-personal" then "github-pat" else lib.removePrefix "llm-assistants/mcp/" name;
      overrides.github-pat.path = "${secrets.secretsPath userCfg.home}/github/pat";
    };
  };
}
