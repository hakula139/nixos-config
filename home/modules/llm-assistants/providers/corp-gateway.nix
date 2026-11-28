# ==================================================================================================
# Corporate Gateway Provider
# ==================================================================================================

{
  lib,
  corpHosts,
  modelCatalog,
  resolvedClaudeProfiles,
  secretPath,
}:

let
  baseUrl = corpHosts.llmGatewayUrl;
  caSecret = "llm-assistants/corp-gateway/cachain.crt";
  portalTokenSecret = "llm-assistants/corp-gateway/portal-token";
  tokenSecretFor = client: "llm-assistants/corp-gateway/api-key/${client}";
  prosePolishSecret = tokenSecretFor "prose-polish";

  # The gateway injects its MCP tools into every model request unless this header names the clients
  # to keep. Naming none keeps the tools on the MCP server, and OMP drops empty header values, so
  # it cannot be blank.
  extraHeaders.x-bf-mcp-include-clients = "none";

  # ------------------------------------------------------------------------------------------------
  # Channels and profiles
  # ------------------------------------------------------------------------------------------------
  channels = {
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
      nativeWebSearch = false;
    };

    local = {
      family = "local";
      nativeWebSearch = false;
    };
  };

  channelProfiles = lib.mapAttrs' (
    channel: spec:
    lib.nameValuePair "corp-gateway-${channel}" (
      spec
      // {
        inherit channel;
        provider = "corp-gateway";
      }
    )
  ) channels;

  # ------------------------------------------------------------------------------------------------
  # Claude Code per-profile workarounds
  # ------------------------------------------------------------------------------------------------
  localMiniKey = modelCatalog.defaults.local.mini;
  localMiniModel = modelCatalog.models.${localMiniKey};
  localMiniId = localMiniModel.channelId.local or localMiniKey;
  localMiniAliasId =
    localMiniId + lib.optionalString (localMiniModel.contextWindow >= 1000000) "[1m]";

  localDefaultModel = modelCatalog.models.${modelCatalog.defaults.local.default};

  claudeModelId =
    workload: if workload.channel == "anthropic" then workload.modelKey else workload.modelId;

  smallFastIdFor = name: claudeModelId resolvedClaudeProfiles.${name}.workloads.mini;

  mkClaudeProfileOverrides =
    {
      smallFastId,
      extraEnv ? { },
      extraAttrs ? { },
    }:
    {
      extraEnv = {
        # Undocumented: `-` clears `rejects_disabled_thinking` (matched against lowercased model
        # IDs), which Claude Code assumes on Haiku 5.5 and uncataloged gateway models, so prompt
        # hooks and the auto-mode classifier disable thinking.
        CLAUDE_CODE_MODEL_CAPABILITIES = "${lib.toLower smallFastId}=-rejects_disabled_thinking";
      }
      // extraEnv;
    }
    // extraAttrs;

  claudeProfileOverrides = {
    corp-gateway-anthropic = mkClaudeProfileOverrides {
      smallFastId = smallFastIdFor "corp-gateway-anthropic";
    };

    corp-gateway-openai = mkClaudeProfileOverrides {
      smallFastId = smallFastIdFor "corp-gateway-openai";
      extraAttrs.nativeWebSearch = false;
    };

    corp-gateway-google = mkClaudeProfileOverrides {
      smallFastId = localMiniId;
      extraEnv = {
        # OpenRouter streams Gemini's `thoughtSignature` as a trailing `redacted_thinking` block
        # after `text`, and Claude Code's single-turn helper keeps only the last block, emptying
        # prompt-hook and side-query replies while leaving Haiku-tier agents unaffected.
        ANTHROPIC_SMALL_FAST_MODEL = localMiniAliasId;
        CLAUDE_CODE_AUTO_MODE_MODEL = localMiniId;
      };
    };

    corp-gateway-local = mkClaudeProfileOverrides {
      smallFastId = smallFastIdFor "corp-gateway-local";
      extraEnv.CLAUDE_CODE_MAX_CONTEXT_TOKENS = toString localDefaultModel.contextWindow;
    };

    corp-gateway-hybrid = mkClaudeProfileOverrides {
      smallFastId = smallFastIdFor "corp-gateway-hybrid";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Client API keys
  # ------------------------------------------------------------------------------------------------
  providerClients = [
    "claude-code"
    "codex"
    "omp"
    "oxide-code"
  ];
in
{
  providers.corp-gateway = {
    inherit baseUrl;

    apiUrls = {
      anthropic-messages = "${baseUrl}/anthropic";
      openai-responses = "${baseUrl}/v1";
    };

    clientApiKeyFiles = lib.genAttrs providerClients (client: secretPath (tokenSecretFor client));
    caCertFile = secretPath caSecret;
    inherit extraHeaders;
    extraEnv.CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
    inherit channels;
  };

  profiles = channelProfiles // {
    corp-gateway-hybrid = {
      provider = "corp-gateway";
      defaultsKey = "hybrid";
    };
  };

  modelCall = {
    enable = true;
    provider = "corp-gateway";
    clientApiKeyFiles.prose-polish = secretPath prosePolishSecret;
  };

  inherit claudeProfileOverrides;

  costSources = [
    {
      id = "corp-gateway";

      match.env_prefix = {
        ANTHROPIC_BASE_URL = baseUrl;
      };

      source = {
        type = "http";
        url = "${corpHosts.llmGatewayPortalUrl}/api/portal/monitoring/kpi";
        query = {
          start_time = "{start_utc}";
          end_time = "{end_utc}";
          owner = "self";
        };
        auth = {
          type = "bearer_file";
          path = secretPath portalTokenSecret;
        };
        ca_file = secretPath caSecret;
        no_proxy = true;
        extract = [
          "current"
          "total_cost"
        ];
      };
    }
  ];

  requiredSecrets = map tokenSecretFor providerClients ++ [
    prosePolishSecret
    caSecret
    portalTokenSecret
  ];
}
