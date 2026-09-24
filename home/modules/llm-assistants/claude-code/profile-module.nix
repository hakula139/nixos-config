# ==============================================================================
# Claude Code Profile Module
# ==============================================================================

{
  lib,
  families,
  defaultCompactWindow,
}:

lib.types.submodule {
  options = {
    type = lib.mkOption {
      type = lib.types.enum [
        "subscription"
        "oauth-token"
        "api-key"
      ];
      default = "api-key";
      description = "Authentication type";
    };

    family = lib.mkOption {
      type = lib.types.enum families;
      default = "claude";
      description = "Model family for session and agent effort";
    };

    baseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        API base URL (required for `api-key`, forbidden for `oauth-token` and
        `subscription`).
      '';
    };

    tokenSecret = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Name of the agenix secret containing the auth token (required for
        `oauth-token` and `api-key`, forbidden for `subscription`).
      '';
    };

    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for this profile";
    };

    extraSecretEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Environment variables whose values are absolute paths to provisioned
        secrets. Keys are env var names, values are secret names; referenced
        secrets are auto-provisioned. Forbidden for `subscription`.
      '';
    };

    modelOverrides = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Anthropic model IDs mapped to provider-specific model IDs";
    };

    nativeWebSearch = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose native WebSearch for this profile";
    };
  };

  config.extraEnv.CLAUDE_CODE_AUTO_COMPACT_WINDOW = lib.mkOptionDefault defaultCompactWindow;
}
