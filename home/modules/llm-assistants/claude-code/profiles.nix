# ==================================================================================================
# Claude Code Auth Profiles
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  modelCatalog,
  shared,
  mcpFlag,
  enabledAgents,
}:

let
  inherit (shared.profileDefinitions)
    mkOptions
    mkProfiles
    modelAliases
    roleTiers
    workloadPolicy
    ;

  cfg = config.hakula.claude-code;
  json = pkgs.formats.json { };
  stateDir = "${config.xdg.stateHome}/claude-code";

  # ------------------------------------------------------------------------------------------------
  # Profile assembly
  # ------------------------------------------------------------------------------------------------
  anthropicModels = lib.filterAttrs (_: model: model.channelId ? anthropic) modelCatalog.models;

  # Claude Code recognizes catalog keys, and `modelOverrides` maps them to gateway IDs.
  clientModelId =
    workload: if workload.channel == "anthropic" then workload.modelKey else workload.modelId;

  aliasModelId =
    workload:
    clientModelId workload + lib.optionalString (workload.model.contextWindow >= 1000000) "[1m]";

  mkProfile =
    _: profile:
    let
      inherit (profile) roles workloads;

      defaultTier = lib.findFirst (tier: workloads.${tier}.modelKey == workloads.default.modelKey) null [
        "flagship"
        "standard"
      ];

      defaultModel =
        if defaultTier != null then modelAliases.claude.${defaultTier} else aliasModelId workloads.default;

      aliasEnv =
        lib.mapAttrs' (
          tier: alias:
          lib.nameValuePair "ANTHROPIC_DEFAULT_${lib.toUpper alias}_MODEL" (aliasModelId workloads.${tier})
        ) modelAliases.claude
        // {
          ANTHROPIC_DEFAULT_MODEL = defaultModel;
          CLAUDE_CODE_SUBAGENT_MODEL = modelAliases.claude.${roleTiers.task.modelTier};
        };

      auth = shared.anthropicProfiles.mkProfileAuth {
        client = "claude-code";
        caEnvVar = "NODE_EXTRA_CA_CERTS";
      } profile;

      isCorpGateway = profile.provider == "corp-gateway";

      usesSmallFastFallback = isCorpGateway && workloads.mini.channel == "google";
      smallFastWorkload =
        if usesSmallFastFallback then
          resolvedProfiles.corp-gateway-local.workloads.mini
        else
          workloads.mini;
      smallFastId = clientModelId smallFastWorkload;

      corpGatewayEnv = {
        # Undocumented: `-` clears `rejects_disabled_thinking` (matched against lowercased model
        # IDs), which Claude Code assumes on Haiku 5.5 and uncataloged gateway models, so prompt
        # hooks and the auto-mode classifier disable thinking.
        CLAUDE_CODE_MODEL_CAPABILITIES = "${lib.toLower smallFastId}=-rejects_disabled_thinking";
      }
      // lib.optionalAttrs (roles.default.family == "local") {
        CLAUDE_CODE_MAX_CONTEXT_TOKENS = toString roles.default.model.contextWindow;
      }
      // lib.optionalAttrs usesSmallFastFallback {
        # OpenRouter streams Gemini's `thoughtSignature` as a trailing `redacted_thinking` block
        # after `text`, and Claude Code's single-turn helper keeps only the last block, emptying
        # prompt-hook and side-query replies while leaving Haiku-tier agents unaffected.
        ANTHROPIC_SMALL_FAST_MODEL = aliasModelId smallFastWorkload;
      };

      # Only the gateway's Bedrock route is known to return `safeguard_results`, so other routes opt
      # out of server checks and run the local auto-mode classifier on the small-fast model.
      autoModeServerOptOut =
        profile.provider != null
        && lib.any (tier: workloads.${tier}.channel != "anthropic") (
          builtins.attrNames modelAliases.claude
        );
    in
    auth
    // {
      extraEnv =
        aliasEnv
        // auth.extraEnv or { }
        // lib.optionalAttrs isCorpGateway corpGatewayEnv
        // lib.optionalAttrs autoModeServerOptOut {
          CLAUDE_CODE_AUTO_MODE_MODEL = smallFastId;
          CLAUDE_CODE_AUTO_MODE_SERVER = "0";
        };

      nativeWebSearch = profile.nativeWebSearch && !isCorpGateway;
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

      agentModels = lib.mapAttrs (
        tier: workload:
        if tier == "prose" && isCorpGateway then
          aliasModelId workload
        else if tier == "default" then
          defaultModel
        else
          modelAliases.claude.${tier} or modelAliases.claude.flagship
      ) workloads;

      efforts = lib.mapAttrs (_: workload: workload.effort) workloads;
      modelOverrides = lib.optionalAttrs (lib.any (workload: workload.channel == "anthropic") (
        builtins.attrValues workloads
      )) (lib.mapAttrs (_: model: model.channelId.anthropic) anthropicModels);
    };

  # ------------------------------------------------------------------------------------------------
  # Profile definitions
  # ------------------------------------------------------------------------------------------------
  resolvedProfiles = mkProfiles {
    inherit (cfg.auth) enableCorpGateway;
    nativeFamily = "claude";

    providers = [
      "corp-gateway"
      "ikuncode"
      "yescode"
    ];

    channels = [
      "anthropic"
      "openai"
      "google"
      "local"
    ];
  };

  profiles = lib.mapAttrs mkProfile resolvedProfiles;

  # ------------------------------------------------------------------------------------------------
  # Profile submodule
  # ------------------------------------------------------------------------------------------------
  profileType = import ./profile-module.nix {
    inherit lib;
    officialProfile = profiles.official;
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
  # Custom agents
  # ------------------------------------------------------------------------------------------------
  mkAgentsDir =
    {
      agentModels,
      efforts,
    }:
    let
      agents = import ./agents {
        inherit
          lib
          shared
          agentModels
          efforts
          enabledAgents
          ;
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
          permissions.deny = [
            "WebSearch"
          ];
        }
      );

      envScript = pkgs.writeShellScript "claude-profile-${name}" (
        lib.concatStringsSep "\n" (
          shared.anthropicProfiles.mkEnvLines { label = "claude"; } profile
          ++ [ "__claude_settings=${esc settings}" ]
        )
      );
    in
    pkgs.linkFarm "claude-profile-${name}" {
      "env.sh" = envScript;
      agents = mkAgentsDir {
        inherit (profile) agentModels efforts;
      };
    };

  profileBundles = lib.mapAttrs mkProfileBundle cfg.auth.profiles;

  # ------------------------------------------------------------------------------------------------
  # Profile loader
  # ------------------------------------------------------------------------------------------------
  profileEnvVars = shared.anthropicProfiles.mkProfileEnvVars { } cfg.auth.profiles;

  profileLoader = pkgs.replaceVars ./scripts/profile-loader.sh {
    inherit stateDir;
    profileEnvVars = toString profileEnvVars;
  };

  sessionArgs = pkgs.replaceVars ./scripts/session-args.sh {
    inherit mcpFlag;
  };

  # ------------------------------------------------------------------------------------------------
  # Profile switcher
  # ------------------------------------------------------------------------------------------------
  switch = shared.mkProfileSwitch {
    inherit stateDir;
    inherit (cfg.auth) defaultProfile;
    name = "claude-switch";
    assistant = "Claude Code";
    extension = "d";
    profiles = profileBundles;
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
    mkOptions {
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
      switch.assertion
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
    ) profiles;

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = shared.anthropicProfiles.mkRequiredSecrets cfg.auth.profiles;

    # ----------------------------------------------------------------------------------------------
    # Packages
    # ----------------------------------------------------------------------------------------------
    home.packages = [ switch.package ];

    # ----------------------------------------------------------------------------------------------
    # Profile files
    # ----------------------------------------------------------------------------------------------
    home.file = switch.files // {
      ".claude/agents".source = config.lib.file.mkOutOfStoreSymlink "${stateDir}/active-profile/agents";
    };

    # ----------------------------------------------------------------------------------------------
    # Activation
    # ----------------------------------------------------------------------------------------------
    home.activation.claudeCodeProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe switch.package} --initialize
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
    processWrapper = "${processWrapper}";
  };
}
