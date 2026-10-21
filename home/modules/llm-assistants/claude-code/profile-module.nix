# ==================================================================================================
# Claude Code Profile Module
# ==================================================================================================

{
  lib,
  defaultSessionEffort,
  defaultEfforts,
  defaultCompactWindows,
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

    sessionEffort = lib.mkOption {
      type = lib.types.str;
      default = defaultSessionEffort;
      description = "Reasoning effort for the main session";
    };

    modelEfforts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Reasoning effort for each model ID, replacing `sessionEffort` for that model";
    };

    compactWindows = lib.mkOption {
      type = lib.types.attrsOf lib.types.ints.positive;
      default = defaultCompactWindows;
      description = "Auto-compaction window in tokens for each model ID";
    };

    efforts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = defaultEfforts;
      description = "Reasoning effort for each model tier, used by custom agents";
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

    extraHeaders = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional HTTP headers for this profile's API requests";
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
}
