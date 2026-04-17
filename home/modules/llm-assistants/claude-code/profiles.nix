# ==============================================================================
# Claude Code Auth Profiles
# ==============================================================================

{
  config,
  pkgs,
  lib,
  secrets,
  isNixOS ? false,
}:

let
  cfg = config.hakula.claude-code;
  homeDir = config.home.homeDirectory;
  secretsDir = secrets.secretsPath homeDir;
  secretFile = name: lib.escapeShellArg "${secretsDir}/${name}";
  hasProfiles = cfg.auth.profiles != { };

  # ----------------------------------------------------------------------------
  # Profile submodule
  # ----------------------------------------------------------------------------
  profileType = lib.types.submodule {
    options = {
      type = lib.mkOption {
        type = lib.types.enum [
          "oauth-token"
          "api-key"
        ];
        default = "api-key";
        description = "Authentication type";
      };

      tokenSecret = lib.mkOption {
        type = lib.types.str;
        description = "Name of the agenix secret containing the auth token";
      };

      baseUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "API base URL (required for `api-key`, forbidden for `oauth-token`)";
      };

      modelOverrides = {
        opus = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Override for ANTHROPIC_DEFAULT_OPUS_MODEL";
        };
        sonnet = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Override for ANTHROPIC_DEFAULT_SONNET_MODEL";
        };
        haiku = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Override for ANTHROPIC_DEFAULT_HAIKU_MODEL";
        };
      };

      extraEnv = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Additional environment variables for this profile";
      };

      extraSecrets = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional secrets to provision for this profile";
      };
    };
  };

  # ----------------------------------------------------------------------------
  # Required secrets (union across all profiles)
  # ----------------------------------------------------------------------------
  requiredSecrets = lib.unique (
    lib.concatMap (p: [ p.tokenSecret ] ++ p.extraSecrets) (builtins.attrValues cfg.auth.profiles)
  );

  mkProvisioned =
    secretName:
    secrets.mkHomeSecret {
      name = secretName;
      inherit homeDir;
    };

  # ----------------------------------------------------------------------------
  # Profile script generation
  # ----------------------------------------------------------------------------
  readSecretFn = ''
    __read_secret() {
      if [ ! -s "$1" ]; then
        echo "claude: secret file missing or empty: $1" >&2
        return 1
      fi
      cat "$1"
    }
  '';

  mkProfileScript =
    name: profile:
    let
      isOAuth = profile.type == "oauth-token";
      esc = lib.escapeShellArg;
      sf = secretFile profile.tokenSecret;

      lines = [
        readSecretFn
        (
          if isOAuth then
            ''export CLAUDE_CODE_OAUTH_TOKEN="$(__read_secret ${sf})"''
          else
            ''export ANTHROPIC_AUTH_TOKEN="$(__read_secret ${sf})"''
        )
      ]
      ++ lib.optional (profile.baseUrl != null) "export ANTHROPIC_BASE_URL=${esc profile.baseUrl}"
      ++ lib.optional (
        profile.modelOverrides.opus != null
      ) "export ANTHROPIC_DEFAULT_OPUS_MODEL=${esc profile.modelOverrides.opus}"
      ++ lib.optional (
        profile.modelOverrides.sonnet != null
      ) "export ANTHROPIC_DEFAULT_SONNET_MODEL=${esc profile.modelOverrides.sonnet}"
      ++ lib.optional (
        profile.modelOverrides.haiku != null
      ) "export ANTHROPIC_DEFAULT_HAIKU_MODEL=${esc profile.modelOverrides.haiku}"
      ++ lib.mapAttrsToList (k: v: "export ${k}=${esc v}") profile.extraEnv;
    in
    pkgs.writeShellScript "claude-profile-${name}" (lib.concatStringsSep "\n" lines);

  profileScripts = lib.mapAttrs mkProfileScript cfg.auth.profiles;

  # ----------------------------------------------------------------------------
  # All auth env var names (union for reset)
  # ----------------------------------------------------------------------------
  allAuthEnvVars = lib.unique (
    lib.concatMap (
      profile:
      let
        baseVars =
          if profile.type == "oauth-token" then
            [ "CLAUDE_CODE_OAUTH_TOKEN" ]
          else
            [ "ANTHROPIC_AUTH_TOKEN" ] ++ lib.optional (profile.baseUrl != null) "ANTHROPIC_BASE_URL";
        modelVars =
          lib.optional (profile.modelOverrides.opus != null) "ANTHROPIC_DEFAULT_OPUS_MODEL"
          ++ lib.optional (profile.modelOverrides.sonnet != null) "ANTHROPIC_DEFAULT_SONNET_MODEL"
          ++ lib.optional (profile.modelOverrides.haiku != null) "ANTHROPIC_DEFAULT_HAIKU_MODEL";
        extraVars = builtins.attrNames profile.extraEnv;
      in
      baseVars ++ modelVars ++ extraVars
    ) (builtins.attrValues cfg.auth.profiles)
  );

  # ----------------------------------------------------------------------------
  # Profile loader (sourced by wrapper at startup)
  # ----------------------------------------------------------------------------
  stateDir = "${homeDir}/.local/state/claude-code";

  profileLoader = pkgs.writeShellScript "claude-profile-loader" (
    builtins.replaceStrings
      [
        "@unsetVars@"
        "@stateDir@"
      ]
      [
        (lib.concatMapStringsSep "\n" (v: "unset ${v}") allAuthEnvVars)
        stateDir
      ]
      (builtins.readFile ./scripts/profile-loader.sh)
  );

  # ----------------------------------------------------------------------------
  # claude-switch script
  # ----------------------------------------------------------------------------
  profileNames = builtins.attrNames cfg.auth.profiles;

  claudeSwitch = pkgs.writeShellScriptBin "claude-switch" (
    builtins.replaceStrings
      [
        "@stateDir@"
        "@profileNames@"
      ]
      [
        stateDir
        (lib.escapeShellArgs profileNames)
      ]
      (builtins.readFile ./scripts/claude-switch.sh)
  );

  # ----------------------------------------------------------------------------
  # Home files (deploy profile scripts to state dir)
  # ----------------------------------------------------------------------------
  homeFiles = lib.mapAttrs' (name: script: {
    name = ".local/state/claude-code/profiles/${name}.sh";
    value = {
      source = script;
    };
  }) profileScripts;

  # ----------------------------------------------------------------------------
  # Activation (create default symlink if missing or broken)
  # ----------------------------------------------------------------------------
  activation =
    if hasProfiles && cfg.auth.defaultProfile != null then
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        __dir="${stateDir}"
        __link="$__dir/active-profile"
        if [ ! -e "$__link" ]; then
          mkdir -p "$__dir"
          ln -sf "$__dir/profiles/${cfg.auth.defaultProfile}.sh" "$__link"
        fi
      ''
    else
      lib.hm.dag.entryAfter [ "writeBoundary" ] "";
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options = {
    defaultProfile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Name of the active auth profile after rebuild (null = no auth)";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf profileType;
      default = { };
      description = "Named authentication profiles for Claude Code";
    };

    _provision.requiredSecrets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      internal = true;
      readOnly = true;
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkMerge [
    {
      assertions =
        lib.optional (cfg.auth.defaultProfile != null && hasProfiles) {
          assertion = lib.hasAttr cfg.auth.defaultProfile cfg.auth.profiles;
          message = "hakula.claude-code: auth.defaultProfile '${cfg.auth.defaultProfile}' is not in auth.profiles";
        }
        ++ lib.optional (hasProfiles && cfg.auth.defaultProfile == null) {
          assertion = false;
          message = "hakula.claude-code: auth.defaultProfile must be set when profiles are defined";
        }
        ++ lib.concatLists (
          lib.mapAttrsToList (name: profile: [
            {
              assertion = profile.type == "api-key" -> profile.baseUrl != null;
              message = "hakula.claude-code: profile '${name}' (api-key) requires baseUrl";
            }
            {
              assertion =
                profile.type == "oauth-token"
                -> (
                  profile.baseUrl == null
                  && profile.modelOverrides.opus == null
                  && profile.modelOverrides.sonnet == null
                  && profile.modelOverrides.haiku == null
                );
              message = "hakula.claude-code: profile '${name}' (oauth-token) must not set baseUrl or modelOverrides";
            }
            {
              assertion = builtins.all (k: builtins.match "[A-Za-z_][A-Za-z0-9_]*" k != null) (
                builtins.attrNames profile.extraEnv
              );
              message = "hakula.claude-code: profile '${name}' has extraEnv keys that are not valid POSIX variable names";
            }
          ]) cfg.auth.profiles
        );

      hakula.claude-code.auth._provision.requiredSecrets = requiredSecrets;
    }

    (lib.mkIf (!isNixOS && hasProfiles) {
      age.secrets = builtins.listToAttrs (
        map (secretName: {
          name = lib.replaceStrings [ "." ] [ "-" ] secretName;
          value = mkProvisioned secretName;
        }) requiredSecrets
      );
    })
  ];

  # ----------------------------------------------------------------------------
  # Exports consumed by default.nix
  # ----------------------------------------------------------------------------
  wrapArgs = lib.optionals hasProfiles [
    "--run"
    "source ${profileLoader}"
  ];

  packages = lib.optionals hasProfiles [ claudeSwitch ];

  inherit homeFiles activation;
}
