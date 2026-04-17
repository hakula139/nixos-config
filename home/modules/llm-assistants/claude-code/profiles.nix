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

  modelEnvVars = {
    opus = "ANTHROPIC_DEFAULT_OPUS_MODEL";
    sonnet = "ANTHROPIC_DEFAULT_SONNET_MODEL";
    haiku = "ANTHROPIC_DEFAULT_HAIKU_MODEL";
  };

  # ----------------------------------------------------------------------------
  # Profile submodule
  # ----------------------------------------------------------------------------
  profileType = lib.types.submodule {
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

      tokenSecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Name of the agenix secret containing the auth token (not used for `subscription`)";
      };

      baseUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "API base URL (required for `api-key`, forbidden for `oauth-token`)";
      };

      modelOverrides = lib.mapAttrs (
        _: envVar:
        lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Override for ${envVar}";
        }
      ) modelEnvVars;

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
    lib.concatMap (p: lib.optional (p.tokenSecret != null) p.tokenSecret ++ p.extraSecrets) (
      builtins.attrValues cfg.auth.profiles
    )
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
      if [[ ! -s "$1" ]]; then
        echo "claude: secret file missing or empty: $1" >&2
        return 1
      fi
      cat "$1"
    }
  '';

  mkProfileScript =
    name: profile:
    let
      esc = lib.escapeShellArg;

      tokenLines =
        if profile.type == "subscription" then
          [ "# subscription mode: auth via interactive OAuth (.credentials.json)" ]
        else
          let
            sf = secretFile profile.tokenSecret;
          in
          [
            readSecretFn
            (
              if profile.type == "oauth-token" then
                ''export CLAUDE_CODE_OAUTH_TOKEN="$(__read_secret ${sf})"''
              else
                ''export ANTHROPIC_AUTH_TOKEN="$(__read_secret ${sf})"''
            )
          ];

      envLines =
        lib.optional (profile.baseUrl != null) "export ANTHROPIC_BASE_URL=${esc profile.baseUrl}"
        ++ lib.concatLists (
          lib.mapAttrsToList (
            k: envVar:
            lib.optional (profile.modelOverrides.${k} != null)
              "export ${envVar}=${esc profile.modelOverrides.${k}}"
          ) modelEnvVars
        )
        ++ lib.mapAttrsToList (k: v: "export ${k}=${esc v}") profile.extraEnv;
    in
    pkgs.writeShellScript "claude-profile-${name}" (lib.concatStringsSep "\n" (tokenLines ++ envLines));

  profileScripts = lib.mapAttrs mkProfileScript cfg.auth.profiles;

  # ----------------------------------------------------------------------------
  # All auth env var names (union for reset)
  # ----------------------------------------------------------------------------
  # Hardcoded blocklist: always unset regardless of which profiles are declared.
  # Prevents externally-set auth vars from bypassing profile switching.
  knownAuthEnvVars = [
    "ANTHROPIC_API_KEY"
    "ANTHROPIC_AUTH_TOKEN"
    "ANTHROPIC_BASE_URL"
    "CLAUDE_CODE_OAUTH_TOKEN"
  ];

  allAuthEnvVars = lib.unique (
    knownAuthEnvVars
    ++ lib.concatMap (
      profile:
      let
        modelVars = lib.concatLists (
          lib.mapAttrsToList (
            k: envVar: lib.optional (profile.modelOverrides.${k} != null) envVar
          ) modelEnvVars
        );
        extraVars = builtins.attrNames profile.extraEnv;
      in
      modelVars ++ extraVars
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
              assertion =
                (profile.type == "oauth-token" || profile.type == "api-key") -> profile.tokenSecret != null;
              message = "hakula.claude-code: profile '${name}' (${profile.type}) requires tokenSecret";
            }
            {
              assertion = profile.type == "api-key" -> profile.baseUrl != null;
              message = "hakula.claude-code: profile '${name}' (api-key) requires baseUrl";
            }
            {
              assertion =
                (profile.type == "oauth-token" || profile.type == "subscription")
                -> (
                  profile.baseUrl == null
                  && builtins.all (k: profile.modelOverrides.${k} == null) (builtins.attrNames modelEnvVars)
                );
              message = "hakula.claude-code: profile '${name}' (${profile.type}) must not set baseUrl or modelOverrides";
            }
            {
              assertion =
                profile.type == "subscription" -> (profile.tokenSecret == null && profile.extraSecrets == [ ]);
              message = "hakula.claude-code: profile '${name}' (subscription) must not set tokenSecret or extraSecrets";
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
