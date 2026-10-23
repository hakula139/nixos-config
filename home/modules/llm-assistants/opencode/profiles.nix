# ==================================================================================================
# OpenCode Auth Profiles
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  sharedAgents,
  enabledAgents,
  profileDefinitions,
  secretPath,
  mkProfileSwitch,
}:

let
  cfg = config.hakula.opencode.auth;
  json = pkgs.formats.json { };
  stateDir = "${config.xdg.stateHome}/opencode";
  managedAgents = lib.filterAttrs (name: _: lib.elem name enabledAgents) sharedAgents;

  corpGateway = profileDefinitions.providers.corp-gateway;
  tokenFile = secretPath (corpGateway.tokenSecretFor "opencode");
  caFile = secretPath corpGateway.caSecret;

  # ------------------------------------------------------------------------------------------------
  # Model configuration
  # ------------------------------------------------------------------------------------------------
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

  mkModel =
    {
      api,
      channel,
      model,
      ...
    }:
    {
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
    // lib.optionalAttrs (channel != null) {
      cost = {
        inherit (model.channelCost.${channel}) input output;
        cache_read = model.channelCost.${channel}.cacheRead;
        cache_write = model.channelCost.${channel}.cacheWrite;
      };
    };

  # ------------------------------------------------------------------------------------------------
  # Provider configuration
  # ------------------------------------------------------------------------------------------------
  sdks = {
    anthropic-messages = {
      name = "anthropic";
      # The native Anthropic client appends /v1/messages. This SDK appends /messages, so its base
      # URL must include /v1.
      baseURL = corpGateway.apiUrls.anthropic-messages + "/v1";
    };

    openai-responses = {
      name = "openai";
      baseURL = corpGateway.apiUrls.openai-responses;
    };
  };

  # Provider IDs persist in sessions independently of profile filenames.
  providerId =
    workload:
    if workload.channel == null then
      sdks.${workload.api}.name
    else if workload.channel == "openai" then
      "corp-gateway"
    else
      workload.source;

  modelRef = workload: "${providerId workload}/${workload.modelId}";

  # Every workload of one provider shares its API and channel.
  mkProvider =
    workloads:
    let
      inherit (lib.head workloads) api channel;
      sdk = sdks.${api};
    in
    {
      models = lib.listToAttrs (
        map (workload: lib.nameValuePair workload.modelId (mkModel workload)) workloads
      );
    }
    // lib.optionalAttrs (channel != null) {
      npm = "@ai-sdk/${sdk.name}";
      options = {
        inherit (sdk) baseURL;
        apiKey = "{file:${tokenFile}}";
        headers = corpGateway.extraHeaders;
      };
    };

  # ------------------------------------------------------------------------------------------------
  # Profile assembly
  # ------------------------------------------------------------------------------------------------
  mkProfile =
    _:
    {
      roles,
      workloads,
      ...
    }:
    let
      mkAgent = workload: {
        model = modelRef workload;
        options = mkReasoningOptions workload.api workload.model workload.effort;
      };
    in
    {
      model = modelRef roles.default;
      small_model = modelRef roles.small;

      agent = {
        build = mkAgent roles.default;
        plan = mkAgent roles.plan;
        general = mkAgent roles.task;

        # Explore runs on the invoking agent's model, while the shared researcher covers the same
        # read-only search on the mini tier.
        explore.disable = true;
      }
      // lib.mapAttrs (_: agent: mkAgent workloads.${agent.workload}) managedAgents;

      provider = lib.mapAttrs (_: mkProvider) (lib.groupBy providerId (builtins.attrValues workloads));
    };

  # ------------------------------------------------------------------------------------------------
  # Profile definitions
  # ------------------------------------------------------------------------------------------------
  profiles = lib.mapAttrs mkProfile (
    profileDefinitions.mkProfiles {
      inherit (cfg) enableCorpGateway;
      nativeFamily = "gpt";
      hybridBase = "corp-gateway-anthropic";

      providers = [ "corp-gateway" ];
      channels = [
        "anthropic"
        "openai"
        "google"
        "local"
      ];
    }
  );

  # ------------------------------------------------------------------------------------------------
  # Profile switcher
  # ------------------------------------------------------------------------------------------------
  switch = mkProfileSwitch {
    inherit stateDir;
    inherit (cfg) defaultProfile;
    name = "opencode-switch";
    assistant = "OpenCode";
    extension = "json";
    profiles = lib.mapAttrs (
      name: settings: json.generate "opencode-profile-${name}.json" settings
    ) profiles;
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options = profileDefinitions.mkOptions {
    defaultProfile = if cfg.enableCorpGateway then "corp-gateway-anthropic" else "official";
    enableCorpGateway = config.hakula.llm-assistants.auth.enableCorpGateway;
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = {
    # ----------------------------------------------------------------------------------------------
    # Assertions
    # ----------------------------------------------------------------------------------------------
    assertions = [ switch.assertion ];

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = lib.mkIf cfg.enableCorpGateway {
      ${corpGateway.tokenSecretFor "opencode"} = { };
      ${corpGateway.caSecret} = { };
    };

    # ----------------------------------------------------------------------------------------------
    # Packages
    # ----------------------------------------------------------------------------------------------
    home.packages = [ switch.package ];

    # ----------------------------------------------------------------------------------------------
    # Profile files
    # ----------------------------------------------------------------------------------------------
    home.file = switch.files;

    # ----------------------------------------------------------------------------------------------
    # Activation
    # ----------------------------------------------------------------------------------------------
    home.activation.opencodeAuthProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe switch.package} --initialize
    '';
  };

  # ------------------------------------------------------------------------------------------------
  # Exports
  # ------------------------------------------------------------------------------------------------
  envVars = {
    OPENCODE_CONFIG = "${stateDir}/active-profile";
  }
  // lib.optionalAttrs cfg.enableCorpGateway {
    NODE_EXTRA_CA_CERTS = caFile;
  };
}
