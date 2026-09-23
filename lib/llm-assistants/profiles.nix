# ==============================================================================
# Shared Assistant Profiles
# ==============================================================================

{
  lib,
  modelCatalog,
  corpHosts,
}:

let
  # ----------------------------------------------------------------------------
  # Workload policy
  # ----------------------------------------------------------------------------
  workloadPolicy = {
    claude = {
      standard = "medium";
      flagship = "xhigh";
      mini = "low";
    };
    gpt = {
      standard = "medium";
      flagship = "high";
      mini = "low";
    };
    local = {
      standard = "high";
      flagship = "max";
      mini = "low";
    };
  };

  # ----------------------------------------------------------------------------
  # Provider profiles
  # ----------------------------------------------------------------------------
  providerProfiles = {
    corp-gateway-bedrock = {
      provider = "corp-gateway";
      gateway = "bedrock";
      family = "claude";
      nativeWebSearch = false;
    };

    corp-gateway-openai = {
      provider = "corp-gateway";
      gateway = "openai";
      family = "gpt";
      nativeWebSearch = true;
    };

    corp-gateway-local = {
      provider = "corp-gateway";
      gateway = "local";
      family = "local";
      nativeWebSearch = false;
    };

    ikuncode = {
      provider = "ikuncode";
      gateway = null;
      family = "claude";
      nativeWebSearch = false;
    };

    yescode = {
      provider = "yescode";
      gateway = null;
      family = "claude";
      nativeWebSearch = false;
    };
  };

  # ----------------------------------------------------------------------------
  # Profile resolution
  # ----------------------------------------------------------------------------
  resolveProfile =
    _: profile:
    let
      modelKeys = modelCatalog.defaults.${profile.family};
      models = lib.mapAttrs (_: id: modelCatalog.models.${id}) modelKeys;
      modelIds = lib.mapAttrs (
        tier: id: if profile.gateway == null then id else models.${tier}.gatewayId.${profile.gateway}
      ) modelKeys;
      resolveWorkload = tier: effort: {
        modelTier = tier;
        model = models.${tier};
        modelId = modelIds.${tier};
        inherit effort;
      };
      workloads = lib.mapAttrs resolveWorkload workloadPolicy.${profile.family};
    in
    profile
    // {
      inherit modelIds models workloads;
      roles = {
        default = workloads.standard;
        plan = workloads.flagship;
        task = workloads.standard;
        small = workloads.mini;
      };
    };
in
{
  inherit workloadPolicy;

  # ----------------------------------------------------------------------------
  # Provider configuration
  # ----------------------------------------------------------------------------
  providers.corp-gateway =
    let
      baseUrl = corpHosts.llmGatewayUrl;
      apiPaths = {
        anthropic-messages = "anthropic";
        openai-responses = "v1";
      };
    in
    {
      inherit baseUrl;
      apiUrls = lib.mapAttrs (_: path: "${baseUrl}/${path}") apiPaths;

      tokenSecret = "llm-assistants/bifrost-api-key";
      caSecret = "llm-assistants/corp-cachain.crt";
    };

  providers.ikuncode = {
    apiUrls.anthropic-messages = "https://api.ikuncode.cc";
    tokenSecret = "llm-assistants/ikuncode-api-key";
  };

  providers.yescode = {
    apiUrls.anthropic-messages = "https://co.yes.vg";
    tokenSecret = "llm-assistants/yescode-api-key";
  };

  # ----------------------------------------------------------------------------
  # Model mappings
  # ----------------------------------------------------------------------------
  familyApis = {
    claude = "anthropic-messages";
    gpt = "openai-responses";
    local = "openai-responses";
  };

  modelAliases = {
    claude = {
      flagship = "opus";
      standard = "sonnet";
      mini = "haiku";
    };
  };

  # ----------------------------------------------------------------------------
  # Profile construction and options
  # ----------------------------------------------------------------------------
  mkProfiles =
    {
      nativeFamily ? null,
      providers,
      gateways,
      enableCorpGateway,
    }:
    let
      officialProfiles = lib.optionalAttrs (nativeFamily != null) {
        official = {
          provider = null;
          gateway = null;
          family = nativeFamily;
          nativeWebSearch = true;
        };
      };
      enabledProviderProfiles = lib.filterAttrs (
        _: profile:
        lib.elem profile.provider providers
        && (profile.gateway == null || lib.elem profile.gateway gateways)
        && (profile.provider != "corp-gateway" || enableCorpGateway)
      ) providerProfiles;
    in
    lib.mapAttrs resolveProfile (officialProfiles // enabledProviderProfiles);

  mkOptions =
    {
      defaultProfile,
      hostType,
    }:
    {
      defaultProfile = lib.mkOption {
        type = lib.types.str;
        default = defaultProfile;
        description = "Fallback authentication profile when no installed profile is active";
      };

      enableCorpGateway = lib.mkOption {
        type = lib.types.bool;
        default = hostType == "work";
        description = "Include corporate gateway profiles and provision their credentials";
      };
    };
}
