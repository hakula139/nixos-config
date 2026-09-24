# ==============================================================================
# Claude Code Auth Profiles
# ==============================================================================

{
  config,
  pkgs,
  lib,
  profileDefinitions,
  sharedAgents,
  enabledAgents,
  hostType,
  secretPath,
  mkProfileSwitch,
  mcpFlag,
}:

let
  inherit (profileDefinitions) modelAliases providers workloadPolicy;

  cfg = config.hakula.claude-code;
  json = pkgs.formats.json { };
  stateDir = "${config.xdg.stateHome}/claude-code";

  authEnvByType = {
    oauth-token = "CLAUDE_CODE_OAUTH_TOKEN";
    api-key = "ANTHROPIC_AUTH_TOKEN";
  };

  # ----------------------------------------------------------------------------
  # Profile assembly
  # ----------------------------------------------------------------------------
  mkProfile =
    _: profile:
    let
      aliasModelIds = if profile.gateway == "anthropic" then profile.modelKeys else profile.modelIds;
      extraEnv =
        lib.mapAttrs' (
          tier: alias:
          lib.nameValuePair "ANTHROPIC_DEFAULT_${lib.toUpper alias}_MODEL" (
            aliasModelIds.${tier} + lib.optionalString (profile.models.${tier}.contextWindow >= 1000000) "[1m]"
          )
        ) modelAliases.claude
        // {
          CLAUDE_CODE_AUTO_COMPACT_WINDOW = toString profile.roles.default.model.autoCompactTokens;
        }
        // lib.optionalAttrs (profile.family == "claude") {
          PROSE_POLISH_ENABLED = "true";
        };
    in
    {
      inherit extraEnv;
      inherit (profile) family nativeWebSearch;
      modelOverrides = lib.optionalAttrs (profile.gateway == "anthropic") (
        lib.mapAttrs' (tier: id: lib.nameValuePair profile.modelKeys.${tier} id) profile.modelIds
      );
    }
    // (
      if profile.provider == null then
        { type = "subscription"; }
      else
        let
          provider = providers.${profile.provider};
        in
        {
          type = "api-key";
          baseUrl = provider.apiUrls.anthropic-messages;
          inherit (provider) tokenSecret;
        }
        // lib.optionalAttrs (profile.provider == "corp-gateway") {
          extraEnv =
            extraEnv
            // {
              CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
            }
            // lib.optionalAttrs (profile.family == "local") {
              CLAUDE_CODE_MAX_CONTEXT_TOKENS = toString profile.roles.default.model.contextWindow;
            };
          extraSecretEnv.NODE_EXTRA_CA_CERTS = provider.caSecret;
          nativeWebSearch = false;
        }
    );

  # ----------------------------------------------------------------------------
  # Profile definitions
  # ----------------------------------------------------------------------------
  profiles = lib.mapAttrs mkProfile (
    profileDefinitions.mkProfiles {
      inherit (cfg.auth) enableCorpGateway;
      nativeFamily = "claude";
      providers = [
        "corp-gateway"
        "ikuncode"
        "yescode"
      ];
      gateways = [
        "anthropic"
        "openai"
        "local"
      ];
    }
  );

  defaultProfiles = profiles // {
    official-token = profiles.official // {
      type = "oauth-token";
      tokenSecret = "llm-assistants/claude-oauth-token";
    };
  };

  # ----------------------------------------------------------------------------
  # Profile submodule
  # ----------------------------------------------------------------------------
  profileType = import ./profile-module.nix {
    inherit lib;
    families = builtins.attrNames workloadPolicy;
    defaultCompactWindow = defaultProfiles.official.extraEnv.CLAUDE_CODE_AUTO_COMPACT_WINDOW;
  };

  # ----------------------------------------------------------------------------
  # Per-profile assertions
  # ----------------------------------------------------------------------------
  fieldConstraints = [
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
      field = "tokenSecret";
      isSet = p: p.tokenSecret != null;
      required = [
        "oauth-token"
        "api-key"
      ];
      forbidden = [ "subscription" ];
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

  # ----------------------------------------------------------------------------
  # Profile authentication
  # ----------------------------------------------------------------------------
  requiredSecretNames = lib.unique (
    lib.concatMap (
      p: lib.optional (p.tokenSecret != null) p.tokenSecret ++ builtins.attrValues p.extraSecretEnv
    ) (builtins.attrValues cfg.auth.profiles)
  );
  requiredSecrets = lib.genAttrs requiredSecretNames (_: { });

  # ----------------------------------------------------------------------------
  # Family configuration
  # ----------------------------------------------------------------------------
  familyConfigs = lib.mapAttrs (
    family: policy:
    let
      agents = import ./agents {
        inherit lib sharedAgents enabledAgents;
        modelAliases = modelAliases.claude;
        workloadPolicy = policy;
      };
    in
    {
      agentsDir = pkgs.linkFarm "claude-code-agents-${family}" (
        lib.mapAttrsToList (name: text: {
          name = ".claude/agents/${name}.md";
          path = pkgs.writeText "claude-code-agent-${family}-${name}.md" text;
        }) agents.files
      );
      settings = {
        effortLevel = policy.standard;
      };
    }
  ) workloadPolicy;

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
      familyConfig = familyConfigs.${profile.family};
      settingsName = if profile.modelOverrides == { } then profile.family else name;
      settings = json.generate "claude-code-settings-${settingsName}.json" (
        familyConfig.settings
        // lib.optionalAttrs (profile.modelOverrides != { }) {
          inherit (profile) modelOverrides;
        }
      );

      tokenLines =
        if profile.type == "subscription" then
          [ "# subscription mode: auth via interactive OAuth (.credentials.json)" ]
        else
          let
            sf = esc (secretPath profile.tokenSecret);
            envVar = authEnvByType.${profile.type};
          in
          [
            readSecretFn
            ''${envVar}="$(__read_secret ${sf})"''
            "export ${envVar}"
          ];

      envLines =
        lib.optional (profile.baseUrl != null) "export ANTHROPIC_BASE_URL=${esc profile.baseUrl}"
        ++ lib.mapAttrsToList (k: v: "export ${k}=${esc v}") profile.extraEnv
        ++ lib.mapAttrsToList (
          k: secretName: "export ${k}=${esc (secretPath secretName)}"
        ) profile.extraSecretEnv;
    in
    pkgs.writeShellScript "claude-profile-${name}" (
      lib.concatStringsSep "\n" (
        tokenLines
        ++ envLines
        # Inline values keep variadic flags from consuming the caller's prompt.
        ++ lib.optional (!profile.nativeWebSearch) ''set -- --disallowedTools=WebSearch "$@"''
        ++ [
          ''
            set -- \
              --add-dir=${esc "${familyConfig.agentsDir}"} \
              --settings=${esc "${settings}"} \
              "$@"
          ''
        ]
      )
    );

  profileScripts = lib.mapAttrs mkProfileScript cfg.auth.profiles;

  # ----------------------------------------------------------------------------
  # Profile loader
  # ----------------------------------------------------------------------------
  # Clear inherited credentials, including ANTHROPIC_API_KEY, so they cannot
  # bypass the active profile.
  knownAuthEnvVars = lib.naturalSort (
    builtins.attrValues authEnvByType
    ++ [
      "ANTHROPIC_API_KEY"
      "ANTHROPIC_BASE_URL"
    ]
  );

  profileEnvVars = lib.unique (
    knownAuthEnvVars
    ++ lib.concatMap (
      profile: builtins.attrNames profile.extraEnv ++ builtins.attrNames profile.extraSecretEnv
    ) (builtins.attrValues cfg.auth.profiles)
  );

  profileLoader = pkgs.writeShellScript "claude-profile-loader" (
    builtins.replaceStrings
      [
        "@unsetVars@"
        "@stateDir@"
      ]
      [
        (lib.concatMapStringsSep "\n" (v: "unset ${v}") profileEnvVars)
        stateDir
      ]
      (builtins.readFile ./scripts/profile-loader.sh)
  );

  # ----------------------------------------------------------------------------
  # Profile switcher
  # ----------------------------------------------------------------------------
  claudeSwitch = mkProfileSwitch {
    inherit stateDir;
    inherit (cfg.auth) defaultProfile;
    name = "claude-switch";
    assistant = "Claude Code";
    profilesDir = "${stateDir}/profiles";
    extension = "sh";
  };

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
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options =
    profileDefinitions.mkOptions {
      inherit hostType;
      defaultProfile = "official";
    }
    // {

      profiles = lib.mkOption {
        type = lib.types.attrsOf profileType;
        default = { };
        description = "Named authentication profiles for Claude Code";
      };
    };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = {
    # --------------------------------------------------------------------------
    # Assertions
    # --------------------------------------------------------------------------
    assertions = [
      {
        assertion = lib.hasAttr cfg.auth.defaultProfile cfg.auth.profiles;
        message = "hakula.claude-code: auth.defaultProfile '${cfg.auth.defaultProfile}' is not in auth.profiles";
      }
    ]
    ++ lib.concatLists (lib.mapAttrsToList mkProfileAssertions cfg.auth.profiles);

    # --------------------------------------------------------------------------
    # Profile defaults
    # --------------------------------------------------------------------------
    hakula.claude-code.auth.profiles = lib.mapAttrs (
      _: profile:
      profile
      // {
        extraEnv = lib.mapAttrs (_: lib.mkDefault) profile.extraEnv;
      }
    ) defaultProfiles;

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    hakula.secrets.required = requiredSecrets;

    # --------------------------------------------------------------------------
    # Packages
    # --------------------------------------------------------------------------
    home.packages = [ claudeSwitch ];

    # --------------------------------------------------------------------------
    # Profile files
    # --------------------------------------------------------------------------
    home.file = lib.mapAttrs' (name: script: {
      name = "${stateDir}/profiles/${name}.sh";
      value = {
        source = script;
      };
    }) profileScripts;

    # --------------------------------------------------------------------------
    # Activation
    # --------------------------------------------------------------------------
    home.activation.claudeCodeProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${lib.getExe claudeSwitch} --initialize
    '';
  };

  # ----------------------------------------------------------------------------
  # Exports
  # ----------------------------------------------------------------------------
  wrapArgs = [
    "--run"
    "source ${profileLoader}"
  ];

  settings = {
    model = modelAliases.claude.standard;
    processWrapper = "${teammateLauncher}";
  };
}
