# ==================================================================================================
# Claude Code Auth Profiles
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  sharedAgents,
  enabledAgents,
  modelCatalog,
  profileDefinitions,
  secretPath,
  mkProfileSwitch,
  mcpFlag,
}:

let
  inherit (profileDefinitions)
    modelAliases
    providers
    roleTiers
    workloadPolicy
    ;

  cfg = config.hakula.claude-code;
  json = pkgs.formats.json { };
  stateDir = "${config.xdg.stateHome}/claude-code";

  authEnvByType = {
    oauth-token = "CLAUDE_CODE_OAUTH_TOKEN";
    api-key = "ANTHROPIC_AUTH_TOKEN";
  };

  # ------------------------------------------------------------------------------------------------
  # Profile assembly
  # ------------------------------------------------------------------------------------------------
  anthropicModels = lib.filterAttrs (_: model: model.channelId ? anthropic) modelCatalog.models;

  mkProfile =
    _: profile:
    let
      inherit (profile) roles workloads;
      # Claude Code recognizes catalog keys, and `modelOverrides` maps them to gateway IDs.
      clientModelId =
        workload: if workload.channel == "anthropic" then workload.modelKey else workload.modelId;

      aliasModelId =
        workload:
        clientModelId workload + lib.optionalString (workload.model.contextWindow >= 1000000) "[1m]";

      extraEnv =
        lib.mapAttrs' (
          tier: alias:
          lib.nameValuePair "ANTHROPIC_DEFAULT_${lib.toUpper alias}_MODEL" (aliasModelId workloads.${tier})
        ) modelAliases.claude
        // {
          CLAUDE_CODE_SUBAGENT_MODEL = modelAliases.claude.${roleTiers.task.modelTier};
        };
    in
    {
      inherit extraEnv;
      inherit (profile) nativeWebSearch;
      sessionEffort = roles.default.effort;
      # Generic subagents and other requests without an effort take the session effort, which other
      # families may reject (DeepSeek has no `medium`), so each model gets its own family's effort.
      modelEfforts = lib.filterAttrs (_: effort: effort != roles.default.effort) (
        lib.listToAttrs (
          map (
            workload:
            lib.nameValuePair (clientModelId workload)
              workloadPolicy.${workload.family}.${roleTiers.default.effortTier}
          ) (builtins.attrValues workloads)
        )
      );

      compactWindows = lib.listToAttrs (
        map (workload: lib.nameValuePair (clientModelId workload) workload.model.autoCompactTokens) (
          builtins.attrValues workloads
        )
      );

      efforts = lib.mapAttrs (_: workload: workload.effort) workloads;
      modelOverrides = lib.optionalAttrs (lib.any (workload: workload.channel == "anthropic") (
        builtins.attrValues workloads
      )) (lib.mapAttrs (_: model: model.channelId.anthropic) anthropicModels);
    }
    // (
      if profile.provider == null then
        { type = "subscription"; }
      else
        let
          inherit (workloads) mini;
          provider = providers.${profile.provider};
        in
        {
          type = "api-key";
          baseUrl = provider.apiUrls.anthropic-messages;
          tokenSecret = provider.tokenSecretFor "claude-code";
          extraHeaders = provider.extraHeaders or { };
        }
        // lib.optionalAttrs (profile.provider == "corp-gateway") {
          extraEnv =
            extraEnv
            // {
              CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
              CLAUDE_CODE_AUTO_MODE_MODEL =
                modelCatalog.models.${modelCatalog.defaults.claude.mini}.channelId.anthropic;
            }
            // lib.optionalAttrs (roles.default.family == "local") {
              CLAUDE_CODE_MAX_CONTEXT_TOKENS = toString roles.default.model.contextWindow;
            }
            // lib.optionalAttrs (mini.channel == "anthropic") {
              # Undocumented: `-` clears a catalog flag, so prompt hooks and the auto-mode
              # classifier on Haiku send the disabled thinking they request, since the gateway's
              # Bedrock streams drop structured replies that think.
              CLAUDE_CODE_MODEL_CAPABILITIES = "${mini.modelKey}=-rejects_disabled_thinking";
            };
          extraSecretEnv.NODE_EXTRA_CA_CERTS = provider.caSecret;
          nativeWebSearch = false;
        }
    );

  # ------------------------------------------------------------------------------------------------
  # Profile definitions
  # ------------------------------------------------------------------------------------------------
  profiles = lib.mapAttrs mkProfile (
    profileDefinitions.mkProfiles {
      inherit (cfg.auth) enableCorpGateway;
      nativeFamily = "claude";
      hybridBase = "corp-gateway-anthropic";

      providers = [
        "corp-gateway"
        "ikuncode"
        "yescode"
      ];

      channels = [
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

  # ------------------------------------------------------------------------------------------------
  # Profile submodule
  # ------------------------------------------------------------------------------------------------
  profileType = import ./profile-module.nix {
    inherit lib;
    defaultSessionEffort = defaultProfiles.official.sessionEffort;
    defaultEfforts = workloadPolicy.claude;
    defaultCompactWindows = defaultProfiles.official.compactWindows;
  };

  # ------------------------------------------------------------------------------------------------
  # Per-profile assertions
  # ------------------------------------------------------------------------------------------------
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

  # ------------------------------------------------------------------------------------------------
  # Profile authentication
  # ------------------------------------------------------------------------------------------------
  requiredSecretNames = lib.unique (
    lib.concatMap (
      p: lib.optional (p.tokenSecret != null) p.tokenSecret ++ builtins.attrValues p.extraSecretEnv
    ) (builtins.attrValues cfg.auth.profiles)
  );

  requiredSecrets = lib.genAttrs requiredSecretNames (_: { });

  # ------------------------------------------------------------------------------------------------
  # Custom agents
  # ------------------------------------------------------------------------------------------------
  mkAgentsDir =
    efforts:
    let
      agents = import ./agents {
        inherit
          lib
          sharedAgents
          enabledAgents
          efforts
          ;
        modelAliases = modelAliases.claude;
      };
    in
    pkgs.linkFarm "claude-code-agents" (
      lib.mapAttrs' (
        name: text: lib.nameValuePair "${name}.md" (pkgs.writeText "claude-code-agent-${name}.md" text)
      ) agents.files
    );

  # ------------------------------------------------------------------------------------------------
  # Profile bundles
  # ------------------------------------------------------------------------------------------------
  readSecretFn = ''
    __read_secret() {
      if [[ ! -s "$1" ]]; then
        echo "claude: secret file missing or empty: $1" >&2
        return 1
      fi
      cat "$1"
    }
  '';

  mkProfileBundle =
    name: profile:
    let
      esc = lib.escapeShellArg;

      modelSettings = lib.zipAttrsWith (_: lib.mergeAttrsList) [
        (lib.mapAttrs (_: effortLevel: { inherit effortLevel; }) profile.modelEfforts)
        (lib.mapAttrs (_: autoCompactWindow: { inherit autoCompactWindow; }) profile.compactWindows)
      ];

      settings = json.generate "claude-code-settings-${name}.json" (
        {
          effortLevel = profile.sessionEffort;
        }
        // lib.optionalAttrs (modelSettings != { }) {
          inherit modelSettings;
        }
        // lib.optionalAttrs (profile.modelOverrides != { }) {
          inherit (profile) modelOverrides;
        }
        // lib.optionalAttrs (!profile.nativeWebSearch) {
          permissions.deny = [ "WebSearch" ];
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
        let
          customHeaders = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (name: value: "${name}: ${value}") profile.extraHeaders
          );
        in
        lib.optional (profile.baseUrl != null) "export ANTHROPIC_BASE_URL=${esc profile.baseUrl}"
        ++ lib.optional (customHeaders != "") "export ANTHROPIC_CUSTOM_HEADERS=${esc customHeaders}"
        ++ lib.mapAttrsToList (k: v: "export ${k}=${esc v}") profile.extraEnv
        ++ lib.mapAttrsToList (
          k: secretName: "export ${k}=${esc (secretPath secretName)}"
        ) profile.extraSecretEnv;

      envScript = pkgs.writeShellScript "claude-profile-${name}" (
        lib.concatStringsSep "\n" (tokenLines ++ envLines ++ [ "__claude_settings=${esc settings}" ])
      );
    in
    pkgs.linkFarm "claude-profile-${name}" {
      "env.sh" = envScript;
      agents = mkAgentsDir profile.efforts;
    };

  profileBundles = lib.mapAttrs mkProfileBundle cfg.auth.profiles;

  # ------------------------------------------------------------------------------------------------
  # Profile loader
  # ------------------------------------------------------------------------------------------------
  # Clear inherited credentials, ANTHROPIC_API_KEY included, so none can bypass the active profile.
  knownAuthEnvVars = lib.naturalSort (
    builtins.attrValues authEnvByType
    ++ [
      "ANTHROPIC_API_KEY"
      "ANTHROPIC_BASE_URL"
      "ANTHROPIC_CUSTOM_HEADERS"
    ]
  );

  profileEnvVars = lib.unique (
    knownAuthEnvVars
    ++ lib.concatMap (
      profile: builtins.attrNames profile.extraEnv ++ builtins.attrNames profile.extraSecretEnv
    ) (builtins.attrValues cfg.auth.profiles)
  );

  profileLoader = pkgs.replaceVars ./scripts/profile-loader.sh {
    profileEnvVars = toString profileEnvVars;
    inherit stateDir;
  };

  sessionArgs = pkgs.replaceVars ./scripts/session-args.sh { inherit mcpFlag; };

  # ------------------------------------------------------------------------------------------------
  # Profile switcher
  # ------------------------------------------------------------------------------------------------
  claudeSwitch = mkProfileSwitch {
    inherit stateDir;
    inherit (cfg.auth) defaultProfile;
    name = "claude-switch";
    assistant = "Claude Code";
    profilesDir = "${stateDir}/profiles";
    extension = "d";
  };

  # ------------------------------------------------------------------------------------------------
  # Process wrapper
  # ------------------------------------------------------------------------------------------------
  processWrapper = pkgs.writeShellScript "claude-process-wrapper" (
    builtins.replaceStrings [ "@profileLoader@" ] [ "${profileLoader}" ] (
      builtins.readFile ./scripts/process-wrapper.sh
    )
  );
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options =
    profileDefinitions.mkOptions {
      defaultProfile = "official";
      enableCorpGateway = config.hakula.llm-assistants.auth.enableCorpGateway;
    }
    // {

      profiles = lib.mkOption {
        type = lib.types.attrsOf profileType;
        default = { };
        description = "Named authentication profiles for Claude Code";
      };
    };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = {
    # ----------------------------------------------------------------------------------------------
    # Assertions
    # ----------------------------------------------------------------------------------------------
    assertions = [
      {
        assertion = lib.hasAttr cfg.auth.defaultProfile cfg.auth.profiles;
        message = "hakula.claude-code: auth.defaultProfile '${cfg.auth.defaultProfile}' is not in auth.profiles";
      }
    ]
    ++ lib.concatLists (lib.mapAttrsToList mkProfileAssertions cfg.auth.profiles);

    # ----------------------------------------------------------------------------------------------
    # Profile defaults
    # ----------------------------------------------------------------------------------------------
    hakula.claude-code.auth.profiles = lib.mapAttrs (
      _: profile:
      profile
      // {
        extraEnv = lib.mapAttrs (_: lib.mkDefault) profile.extraEnv;
      }
    ) defaultProfiles;

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = requiredSecrets;

    # ----------------------------------------------------------------------------------------------
    # Packages
    # ----------------------------------------------------------------------------------------------
    home.packages = [ claudeSwitch ];

    # ----------------------------------------------------------------------------------------------
    # Profile files
    # ----------------------------------------------------------------------------------------------
    home.file =
      lib.mapAttrs' (name: bundle: {
        name = "${stateDir}/profiles/${name}.d";
        value = {
          source = bundle;
        };
      }) profileBundles
      // {
        ".claude/agents".source = config.lib.file.mkOutOfStoreSymlink "${stateDir}/active-profile/agents";
      };

    # ----------------------------------------------------------------------------------------------
    # Activation
    # ----------------------------------------------------------------------------------------------
    home.activation.claudeCodeProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe claudeSwitch} --initialize
    '';
  };

  # ------------------------------------------------------------------------------------------------
  # Exports
  # ------------------------------------------------------------------------------------------------
  wrapArgs = [
    "--run"
    "source ${profileLoader}"

    "--run"
    "source ${sessionArgs}"
  ];

  settings = {
    model = modelAliases.claude.${roleTiers.default.modelTier};
    processWrapper = "${processWrapper}";
  };
}
