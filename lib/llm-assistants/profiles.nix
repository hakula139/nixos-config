# ==================================================================================================
# Shared Assistant Profiles
# ==================================================================================================

{
  lib,
  modelCatalog,
  corpHosts,
}:

let
  # ------------------------------------------------------------------------------------------------
  # Workload policy
  # ------------------------------------------------------------------------------------------------
  workloadPolicy = {
    claude = {
      standard = "medium";
      flagship = "xhigh";
      mini = "low";
    };

    gpt = {
      standard = "medium";
      flagship = "xhigh";
      mini = "low";
    };

    gemini = {
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

  # ------------------------------------------------------------------------------------------------
  # Provider profiles
  # ------------------------------------------------------------------------------------------------
  providerProfiles = {
    corp-gateway-anthropic = {
      provider = "corp-gateway";
      channel = "anthropic";
      family = "claude";
      nativeWebSearch = false;
    };

    corp-gateway-openai = {
      provider = "corp-gateway";
      channel = "openai";
      family = "gpt";
      nativeWebSearch = true;
    };

    corp-gateway-google = {
      provider = "corp-gateway";
      channel = "google";
      family = "gemini";
      nativeWebSearch = false;
    };

    corp-gateway-local = {
      provider = "corp-gateway";
      channel = "local";
      family = "local";
      nativeWebSearch = false;
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

  officialTokenSecrets.claude = "llm-assistants/claude-oauth-token";

  # ------------------------------------------------------------------------------------------------
  # Profile resolution
  # ------------------------------------------------------------------------------------------------
  familyApis = {
    claude = "anthropic-messages";
    gpt = "openai-responses";
    gemini = "openai-responses";
    local = "openai-responses";
  };

  roleTiers = {
    default = {
      modelTier = "flagship";
      effortTier = "standard";
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

  resolveProfile =
    sourceProfiles: name: profile:
    let
      sources = profile.sources or (lib.mapAttrs (_: _: name) workloadPolicy.${profile.family});

      resolveWorkload =
        { modelTier, effortTier }:
        let
          source = sources.${modelTier};
          inherit (sourceProfiles.${source}) channel family;
          modelKey = modelCatalog.defaults.${family}.${modelTier};
          model = modelCatalog.models.${modelKey};
        in
        {
          inherit source channel family;
          api = familyApis.${family};
          inherit modelKey model;
          modelId = if channel == null then modelKey else model.channelId.${channel};
          effort = workloadPolicy.${family}.${effortTier};
        };
    in
    {
      inherit (profile) provider nativeWebSearch;
      oauthTokenSecret = profile.oauthTokenSecret or null;
      workloads = lib.mapAttrs (
        tier: _:
        resolveWorkload {
          modelTier = tier;
          effortTier = tier;
        }
      ) sources;

      roles = lib.mapAttrs (_: resolveWorkload) roleTiers;
    };
in
{
  inherit roleTiers workloadPolicy;

  # ------------------------------------------------------------------------------------------------
  # Provider configuration
  # ------------------------------------------------------------------------------------------------
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

      tokenSecretFor = client: "llm-assistants/corp-gateway/${client}-api-key";
      caSecret = "llm-assistants/corp-gateway/cachain.crt";

      # The gateway injects its MCP tools into every model request unless this header names the
      # clients to keep. Naming none keeps the tools on the MCP server, and OMP drops empty header
      # values, so it cannot be blank.
      extraHeaders.x-bf-mcp-include-clients = "none";
    };

  providers.ikuncode = {
    apiUrls.anthropic-messages = "https://api.ikuncode.cc";
    tokenSecretFor = _: "llm-assistants/ikuncode-api-key";
  };

  providers.yescode = {
    apiUrls.anthropic-messages = "https://co.yes.vg";
    tokenSecretFor = _: "llm-assistants/yescode-api-key";
  };

  # ------------------------------------------------------------------------------------------------
  # Model mappings
  # ------------------------------------------------------------------------------------------------
  modelAliases = {
    claude = {
      flagship = "opus";
      standard = "sonnet";
      mini = "haiku";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Profile construction and options
  # ------------------------------------------------------------------------------------------------
  mkProfiles =
    {
      nativeFamily ? null,
      hybridBase ? null,
      providers,
      channels,
      enableCorpGateway,
    }:
    let
      officialProfiles = lib.optionalAttrs (nativeFamily != null) (
        let
          official = {
            provider = null;
            channel = null;
            family = nativeFamily;
            nativeWebSearch = true;
          };
        in
        {
          inherit official;
        }
        // lib.optionalAttrs (officialTokenSecrets ? ${nativeFamily}) {
          official-token = official // {
            oauthTokenSecret = officialTokenSecrets.${nativeFamily};
          };
        }
      );

      enabledProviderProfiles = lib.filterAttrs (
        _: profile:
        lib.elem profile.provider providers
        && (profile.channel == null || lib.elem profile.channel channels)
        && (profile.provider != "corp-gateway" || enableCorpGateway)
      ) providerProfiles;

      sourceProfiles = officialProfiles // enabledProviderProfiles;

      # The hybrid runs its flagship tier on the `hybridBase` gateway profile, whose family need not
      # match `nativeFamily`, and the other tiers on the local model. Mini-tier work is read-only,
      # and flagship-tier agents review the standard tier's changes.
      hybridProfiles = lib.optionalAttrs (hybridBase != null) {
        corp-gateway-hybrid = {
          provider = "corp-gateway";
          sources = {
            flagship = hybridBase;
            standard = "corp-gateway-local";
            mini = "corp-gateway-local";
          };

          inherit (sourceProfiles.${hybridBase}) nativeWebSearch;
        };
      };

      enabledHybridProfiles = lib.filterAttrs (
        _: profile: lib.all (source: sourceProfiles ? ${source}) (builtins.attrValues profile.sources)
      ) hybridProfiles;
    in
    lib.mapAttrs (resolveProfile sourceProfiles) (sourceProfiles // enabledHybridProfiles);

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
