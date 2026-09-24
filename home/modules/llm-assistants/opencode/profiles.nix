# ==============================================================================
# OpenCode Auth Profiles
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
}:

let
  cfg = config.hakula.opencode.auth;
  json = pkgs.formats.json { };
  stateDir = "${config.xdg.stateHome}/opencode";
  managedAgents = lib.filterAttrs (name: _: lib.elem name enabledAgents) sharedAgents;

  corpGateway = profileDefinitions.providers.corp-gateway;
  tokenFile = secretPath corpGateway.tokenSecret;
  caFile = secretPath corpGateway.caSecret;

  # ----------------------------------------------------------------------------
  # Model configuration
  # ----------------------------------------------------------------------------
  mkReasoningOptions =
    api: model: effort:
    {
      anthropic-messages = {
        inherit effort;
      }
      // lib.optionalAttrs (model.thinking.mode == "anthropic-adaptive") {
        thinking = {
          type = "adaptive";
        }
        // lib.optionalAttrs model.thinking.supportsDisplay {
          display = "summarized";
        };
      };
      openai-responses.reasoningEffort = effort;
    }
    .${api};

  mkModels =
    api:
    {
      gateway,
      models,
      modelIds,
      ...
    }:
    lib.mapAttrs' (tier: model: {
      name = modelIds.${tier};
      value = {
        inherit (model) name;
        limit = {
          context = model.contextWindow;
          output = model.maxTokens;
        };
        modalities = {
          inherit (model) input;
          output = [ "text" ];
        };
        inherit (model) reasoning;
        options = mkReasoningOptions api model model.thinking.defaultLevel;
        variants = lib.genAttrs model.thinking.efforts (mkReasoningOptions api model);
      }
      // lib.optionalAttrs (gateway != null) {
        cost = {
          inherit (model.gatewayCost.${gateway}) input output;
          cache_read = model.gatewayCost.${gateway}.cacheRead;
          cache_write = model.gatewayCost.${gateway}.cacheWrite;
        };
      };
    }) models;

  # ----------------------------------------------------------------------------
  # Profile assembly
  # ----------------------------------------------------------------------------
  mkProfile =
    name:
    profile@{
      family,
      gateway,
      roles,
      workloads,
      ...
    }:
    let
      api = profileDefinitions.familyApis.${family};
      sdk =
        {
          anthropic-messages = {
            name = "anthropic";
            # The native Anthropic client appends /v1/messages.
            # This SDK appends /messages, so its base URL must include /v1.
            baseURL = corpGateway.apiUrls.anthropic-messages + "/v1";
          };
          openai-responses = {
            name = "openai";
            baseURL = corpGateway.apiUrls.openai-responses;
          };
        }
        .${api};

      # Provider IDs persist in sessions independently of profile filenames.
      provider =
        if gateway == null then
          sdk.name
        else if gateway == "openai" then
          "corp-gateway"
        else
          name;

      mkAgent = workload: {
        model = "${provider}/${workload.modelId}";
        options = mkReasoningOptions api workload.model workload.effort;
      };

    in
    {
      model = "${provider}/${roles.default.modelId}";
      small_model = "${provider}/${roles.small.modelId}";

      agent = {
        build = mkAgent roles.default;
        plan = mkAgent roles.plan;
        general = mkAgent roles.task;
      }
      // lib.mapAttrs (_: agent: mkAgent workloads.${agent.workload}) managedAgents;

      provider.${provider} = {
        models = mkModels api profile;
      }
      // lib.optionalAttrs (gateway != null) {
        npm = "@ai-sdk/${sdk.name}";
        options = {
          inherit (sdk) baseURL;
          apiKey = "{file:${tokenFile}}";
        };
      };
    };

  # ----------------------------------------------------------------------------
  # Profile definitions
  # ----------------------------------------------------------------------------
  profiles = lib.mapAttrs mkProfile (
    profileDefinitions.mkProfiles {
      inherit (cfg) enableCorpGateway;
      nativeFamily = "gpt";
      providers = [ "corp-gateway" ];
      gateways = [
        "anthropic"
        "openai"
        "local"
      ];
    }
  );

  # ----------------------------------------------------------------------------
  # Profile switcher
  # ----------------------------------------------------------------------------
  switch = mkProfileSwitch {
    inherit stateDir;
    inherit (cfg) defaultProfile;
    name = "opencode-switch";
    assistant = "OpenCode";
    profilesDir = "${stateDir}/profiles";
    extension = "json";
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options = profileDefinitions.mkOptions {
    inherit hostType;
    defaultProfile = if cfg.enableCorpGateway then "corp-gateway-openai" else "official";
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
        assertion = builtins.hasAttr cfg.defaultProfile profiles;
        message = "hakula.opencode.auth.defaultProfile requires its profile to be enabled";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    hakula.secrets.required = lib.mkIf cfg.enableCorpGateway {
      ${corpGateway.tokenSecret} = { };
      ${corpGateway.caSecret} = { };
    };

    # --------------------------------------------------------------------------
    # Packages
    # --------------------------------------------------------------------------
    home.packages = [ switch ];

    # --------------------------------------------------------------------------
    # Profile files
    # --------------------------------------------------------------------------
    home.file = lib.mapAttrs' (name: settings: {
      name = "${stateDir}/profiles/${name}.json";
      value.source = json.generate "opencode-profile-${name}.json" settings;
    }) profiles;

    # --------------------------------------------------------------------------
    # Activation
    # --------------------------------------------------------------------------
    home.activation.opencodeAuthProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${lib.getExe switch} --initialize
    '';
  };

  # ----------------------------------------------------------------------------
  # Exports
  # ----------------------------------------------------------------------------
  envVars = {
    OPENCODE_CONFIG = "${stateDir}/active-profile";
  }
  // lib.optionalAttrs cfg.enableCorpGateway {
    NODE_EXTRA_CA_CERTS = caFile;
  };
}
