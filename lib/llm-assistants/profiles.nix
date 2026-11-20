# ==================================================================================================
# Shared Assistant Profiles
# ==================================================================================================

{
  lib,
  corpHosts,
  modelCatalog,
}:

let
  # ------------------------------------------------------------------------------------------------
  # Workload policy
  # ------------------------------------------------------------------------------------------------
  workloadPolicy = {
    claude = {
      default = "medium";
      flagship = "high";
      standard = "medium";
      mini = "low";
    };

    gpt = {
      default = "medium";
      flagship = "high";
      standard = "medium";
      mini = "low";
    };

    gemini = {
      default = "low";
      flagship = "high";
      standard = "medium";
      mini = "low";
    };

    local = {
      default = "high";
      flagship = "max";
      standard = "high";
      mini = "low";
    };
  };

  roleTiers = {
    default = {
      modelTier = "flagship";
      effortTier = "default";
    };

    plan = {
      modelTier = "flagship";
      effortTier = "flagship";
    };

    task = {
      modelTier = "standard";
      effortTier = "standard";
    };

    small = {
      modelTier = "mini";
      effortTier = "mini";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Provider profiles
  # ------------------------------------------------------------------------------------------------
  gatewayChannels = {
    anthropic = {
      family = "claude";
      nativeWebSearch = false;
    };

    openai = {
      family = "gpt";
      nativeWebSearch = true;
    };

    google = {
      family = "gemini";
      defaultModelTier = "standard";
      nativeWebSearch = false;
    };

    local = {
      family = "local";
      nativeWebSearch = false;
    };
  };

  providerProfiles =
    lib.mapAttrs' (
      channel: spec:
      lib.nameValuePair "corp-gateway-${channel}" (
        spec
        // {
          inherit channel;
          provider = "corp-gateway";
        }
      )
    ) gatewayChannels
    // {
      corp-gateway-hybrid = {
        provider = "corp-gateway";
        defaultsKey = "hybrid";
      };

      ikuncode = {
        provider = "ikuncode";
        channel = null;
        family = "claude";
        nativeWebSearch = false;
      };

      yescode = {
        provider = "yescode";
        channel = null;
        family = "claude";
        nativeWebSearch = false;
      };
    };

  # ------------------------------------------------------------------------------------------------
  # Profile resolution
  # ------------------------------------------------------------------------------------------------
  familyApis = {
    claude = "anthropic-messages";
    gpt = "openai-responses";
    gemini = "openai-responses";
    local = "openai-responses";
  };

  modelChannel = modelKey: lib.head (builtins.attrNames modelCatalog.models.${modelKey}.channelId);

  profileTierModels = profile: modelCatalog.defaults.${profile.defaultsKey or profile.family};

  mkWorkload =
    {
      source,
      channel,
      family,
      modelKey,
      modelId,
      effortTier,
    }:
    {
      inherit
        source
        channel
        family
        modelKey
        modelId
        ;
      api = familyApis.${family};
      model = modelCatalog.models.${modelKey};
      effort = workloadPolicy.${family}.${effortTier};
    };

  resolveGatewayModel =
    {
      modelKey,
      effortTier,
    }:
    let
      model = modelCatalog.models.${modelKey};
      channel = modelChannel modelKey;
    in
    mkWorkload {
      inherit channel modelKey effortTier;
      source = "corp-gateway-${channel}";
      inherit (gatewayChannels.${channel}) family;
      modelId = model.channelId.${channel};
    };

  resolveProfile =
    proseSupported: name: profile:
    let
      tierModels = profileTierModels profile;

      resolveWorkload =
        {
          modelTier,
          effortTier,
        }:
        let
          modelKey = tierModels.${modelTier};
        in
        if profile.provider == "corp-gateway" then
          resolveGatewayModel { inherit modelKey effortTier; }
        else
          mkWorkload {
            inherit (profile) channel family;
            inherit modelKey effortTier;
            source = name;
            modelId = modelKey;
          };

      tierWorkloads = lib.mapAttrs (
        tier: _:
        resolveWorkload {
          modelTier = tier;
          effortTier = tier;
        }
      ) tierModels;

      proseWorkload = resolveGatewayModel {
        modelKey = modelCatalog.defaults.prose;
        effortTier = "flagship";
      };

      profileRoleTiers =
        roleTiers
        // lib.optionalAttrs (profile ? defaultModelTier) {
          default = roleTiers.default // {
            modelTier = profile.defaultModelTier;
          };
        };

      roles = lib.mapAttrs (_: resolveWorkload) profileRoleTiers;
    in
    {
      inherit (profile) provider;
      defaultModelTier = profileRoleTiers.default.modelTier;
      nativeWebSearch =
        profile.nativeWebSearch or gatewayChannels.${roles.default.channel}.nativeWebSearch;
      oauthTokenSecret = profile.oauthTokenSecret or null;

      workloads = tierWorkloads // {
        prose =
          if profile.provider == "corp-gateway" && proseSupported then
            proseWorkload
          else
            tierWorkloads.flagship;
      };

      inherit roles;
    };
in
{
  # ------------------------------------------------------------------------------------------------
  # Workload policy
  # ------------------------------------------------------------------------------------------------
  inherit roleTiers workloadPolicy;

  # ------------------------------------------------------------------------------------------------
  # Providers
  # ------------------------------------------------------------------------------------------------
  providers = {
    corp-gateway =
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

        tokenSecretFor = client: "llm-assistants/corp-gateway/${client}-api-key";
        caSecret = "llm-assistants/corp-gateway/cachain.crt";

        # The gateway injects its MCP tools into every model request unless this header names the
        # clients to keep. Naming none keeps the tools on the MCP server, and OMP drops empty header
        # values, so it cannot be blank.
        extraHeaders.x-bf-mcp-include-clients = "none";
      };

    ikuncode = {
      apiUrls.anthropic-messages = "https://api.ikuncode.cc";
      tokenSecretFor = _: "llm-assistants/ikuncode-api-key";
    };

    yescode = {
      apiUrls.anthropic-messages = "https://co.yes.vg";
      tokenSecretFor = _: "llm-assistants/yescode-api-key";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Model aliases
  # ------------------------------------------------------------------------------------------------
  modelAliases = {
    claude = {
      flagship = "opus";
      standard = "sonnet";
      mini = "haiku";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Profile construction
  # ------------------------------------------------------------------------------------------------
  mkProfiles =
    {
      nativeFamily ? null,
      providers,
      channels,
      enableCorpGateway,
    }:
    let
      official = {
        provider = null;
        channel = null;
        family = nativeFamily;
        nativeWebSearch = true;
      };

      officialTokenSecrets.claude = "llm-assistants/claude-oauth-token";

      officialProfiles = lib.optionalAttrs (nativeFamily != null) (
        {
          inherit official;
        }
        // lib.optionalAttrs (officialTokenSecrets ? ${nativeFamily}) {
          official-token = official // {
            oauthTokenSecret = officialTokenSecrets.${nativeFamily};
          };
        }
      );

      gatewayModelSupported = modelKey: lib.elem (modelChannel modelKey) channels;
      proseSupported = gatewayModelSupported modelCatalog.defaults.prose;

      gatewayProfileSupported =
        profile:
        enableCorpGateway
        && lib.all gatewayModelSupported (builtins.attrValues (profileTierModels profile));

      enabledProviderProfiles = lib.filterAttrs (
        _: profile:
        lib.elem profile.provider providers
        && (
          if profile.provider == "corp-gateway" then
            gatewayProfileSupported profile
          else
            profile.channel == null || lib.elem profile.channel channels
        )
      ) providerProfiles;
    in
    lib.mapAttrs (resolveProfile proseSupported) (officialProfiles // enabledProviderProfiles);

  # ------------------------------------------------------------------------------------------------
  # Profile options
  # ------------------------------------------------------------------------------------------------
  mkOptions =
    {
      defaultProfile,
      enableCorpGateway,
    }:
    {
      defaultProfile = lib.mkOption {
        type = lib.types.str;
        default = defaultProfile;
        description = "Fallback authentication profile when no installed profile is active";
      };

      enableCorpGateway = lib.mkOption {
        type = lib.types.bool;
        default = enableCorpGateway;
        description = "Include corporate gateway profiles and provision their credentials";
      };
    };
}
