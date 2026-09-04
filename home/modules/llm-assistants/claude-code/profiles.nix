# ==============================================================================
# Claude Code Auth Profiles
# ==============================================================================

{
  config,
  pkgs,
  lib,
  hostType,
  mcpFlag,
  secretPath,
  ...
}:

let
  cfg = config.hakula.claude-code;
  homeDir = config.home.homeDirectory;
  stateDir = "${homeDir}/.local/state/claude-code";
  hasProfiles = cfg.auth.profiles != { };

  requiredSecretNames = lib.unique (
    lib.concatMap (
      p: lib.optional (p.tokenSecret != null) p.tokenSecret ++ builtins.attrValues p.extraSecretEnv
    ) (builtins.attrValues cfg.auth.profiles)
  );
  requiredSecrets = lib.genAttrs requiredSecretNames (_: { });

  modelEnvVars = {
    opus = "ANTHROPIC_DEFAULT_OPUS_MODEL";
    sonnet = "ANTHROPIC_DEFAULT_SONNET_MODEL";
    haiku = "ANTHROPIC_DEFAULT_HAIKU_MODEL";
  };

  # Which env var carries the auth token for each non-subscription profile type.
  authEnvByType = {
    oauth-token = "CLAUDE_CODE_OAUTH_TOKEN";
    api-key = "ANTHROPIC_AUTH_TOKEN";
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
        description = ''
          Name of the agenix secret containing the auth token (required for
          `oauth-token` and `api-key`, forbidden for `subscription`).
        '';
      };

      baseUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          API base URL (required for `api-key`, forbidden for `oauth-token` and
          `subscription`).
        '';
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

      extraSecretEnv = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = ''
          Environment variables whose values are absolute paths to provisioned
          secrets. Keys are env var names, values are secret names; referenced
          secrets are auto-provisioned. Forbidden for `subscription`.
        '';
      };
    };
  };

  # ----------------------------------------------------------------------------
  # Profile scripts
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
            sf = lib.escapeShellArg (secretPath profile.tokenSecret);
            envVar = authEnvByType.${profile.type};
          in
          [
            readSecretFn
            ''export ${envVar}="$(__read_secret ${sf})"''
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
        ++ lib.mapAttrsToList (k: v: "export ${k}=${esc v}") profile.extraEnv
        ++ lib.mapAttrsToList (
          k: secretName: "export ${k}=${esc (secretPath secretName)}"
        ) profile.extraSecretEnv;
    in
    pkgs.writeShellScript "claude-profile-${name}" (lib.concatStringsSep "\n" (tokenLines ++ envLines));

  profileScripts = lib.mapAttrs mkProfileScript cfg.auth.profiles;

  # ----------------------------------------------------------------------------
  # Auth env vars
  # ----------------------------------------------------------------------------
  # Blocklist: always unset regardless of which profiles are declared. Prevents
  # externally-set auth vars from bypassing profile switching. Covers every env
  # var the profile scripts may export (via authEnvByType or ANTHROPIC_BASE_URL),
  # plus ANTHROPIC_API_KEY, which no profile writes but external callers might.
  knownAuthEnvVars = lib.naturalSort (
    builtins.attrValues authEnvByType
    ++ [
      "ANTHROPIC_API_KEY"
      "ANTHROPIC_BASE_URL"
    ]
  );

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
        extraVars = builtins.attrNames profile.extraEnv ++ builtins.attrNames profile.extraSecretEnv;
      in
      modelVars ++ extraVars
    ) (builtins.attrValues cfg.auth.profiles)
  );

  # ----------------------------------------------------------------------------
  # Profile loader
  # ----------------------------------------------------------------------------
  # Sourced by the claude wrapper at startup to unset stale auth env vars and
  # export the active profile's variables.
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
  # Profile switcher
  # ----------------------------------------------------------------------------
  claudeSwitch = pkgs.writers.writeNuBin "claude-switch" {
    makeWrapperArgs = [
      "--add-flag"
      stateDir
    ];
  } (builtins.readFile ./scripts/claude-switch.nu);

  # ----------------------------------------------------------------------------
  # Teammate launcher
  # ----------------------------------------------------------------------------
  teammateLauncher = pkgs.writeShellScript "claude-teammate-launcher" (
    builtins.replaceStrings
      [
        "@profileLoader@"
        "@mcpFlag@"
      ]
      [
        "${profileLoader}"
        mcpFlag
      ]
      (builtins.readFile ./scripts/teammate-launcher.sh)
  );

  # ----------------------------------------------------------------------------
  # Home files
  # ----------------------------------------------------------------------------
  homeFiles = lib.mapAttrs' (name: script: {
    name = ".local/state/claude-code/profiles/${name}.sh";
    value = {
      source = script;
    };
  }) profileScripts;

  # ----------------------------------------------------------------------------
  # Activation
  # ----------------------------------------------------------------------------
  # Creates the default active-profile symlink on first rebuild if missing.
  activation = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.optionalString (hasProfiles && cfg.auth.defaultProfile != null) ''
      __dir="${stateDir}"
      __link="$__dir/active-profile"
      if [[ ! -e "$__link" ]]; then
        mkdir -p "$__dir"
        ln -sf "$__dir/profiles/${cfg.auth.defaultProfile}.sh" "$__link"
      fi
    ''
  );

  # ----------------------------------------------------------------------------
  # Per-profile assertions
  # ----------------------------------------------------------------------------
  # Declares which auth types require or forbid each field. Order matches the
  # field declarations in profileType above.
  fieldConstraints = [
    {
      field = "tokenSecret";
      isSet = p: p.tokenSecret != null;
      required = [
        "oauth-token"
        "api-key"
      ];
      forbidden = [ "subscription" ];
    }
    {
      field = "baseUrl";
      isSet = p: p.baseUrl != null;
      required = [ "api-key" ];
      forbidden = [
        "oauth-token"
        "subscription"
      ];
    }
    {
      field = "modelOverrides";
      isSet = p: builtins.any (v: v != null) (builtins.attrValues p.modelOverrides);
      forbidden = [
        "oauth-token"
        "subscription"
      ];
    }
    {
      field = "extraSecretEnv";
      isSet = p: p.extraSecretEnv != { };
      forbidden = [ "subscription" ];
    }
  ];

  mkProfileAssertions =
    name: profile:
    let
      prefix = "hakula.claude-code: profile '${name}' (${profile.type})";
      fieldAssertions =
        {
          field,
          isSet,
          required ? [ ],
          forbidden ? [ ],
        }:
        lib.optional (required != [ ]) {
          assertion = lib.elem profile.type required -> isSet profile;
          message = "${prefix} requires ${field}";
        }
        ++ lib.optional (forbidden != [ ]) {
          assertion = lib.elem profile.type forbidden -> !isSet profile;
          message = "${prefix} must not set ${field}";
        };
      mkPosixNameAssertion = field: keys: {
        assertion = builtins.all (k: builtins.match "[A-Za-z_][A-Za-z0-9_]*" k != null) keys;
        message = "${prefix} has ${field} keys that are not valid POSIX variable names";
      };
    in
    lib.concatMap fieldAssertions fieldConstraints
    ++ [
      (mkPosixNameAssertion "extraEnv" (builtins.attrNames profile.extraEnv))
      (mkPosixNameAssertion "extraSecretEnv" (builtins.attrNames profile.extraSecretEnv))
    ];
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

    enableCorpGateway = lib.mkOption {
      type = lib.types.bool;
      default = hostType == "work";
      description = "Include the `corp-gateway-*` profiles. Requires corp-scoped agenix access.";
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = {
    assertions =
      lib.optional (hasProfiles && cfg.auth.defaultProfile == null) {
        assertion = false;
        message = "hakula.claude-code: auth.defaultProfile must be set when profiles are defined";
      }
      ++ lib.optional (hasProfiles && cfg.auth.defaultProfile != null) {
        assertion = lib.hasAttr cfg.auth.defaultProfile cfg.auth.profiles;
        message = "hakula.claude-code: auth.defaultProfile '${cfg.auth.defaultProfile}' is not in auth.profiles";
      }
      ++ lib.concatLists (lib.mapAttrsToList mkProfileAssertions cfg.auth.profiles);

    hakula.secrets.required = requiredSecrets;
  };

  # ----------------------------------------------------------------------------
  # Exports
  # ----------------------------------------------------------------------------
  wrapArgs = lib.optionals hasProfiles [
    "--run"
    "source ${profileLoader}"
  ];

  packages = lib.optionals hasProfiles [ claudeSwitch ];

  settings = lib.optionalAttrs hasProfiles {
    processWrapper = "${teammateLauncher}";
  };

  inherit homeFiles activation;
}
