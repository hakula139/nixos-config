# ==================================================================================================
# Corporate Gateway Provider
# ==================================================================================================

{
  lib,
  inputs,
  corpHosts,
  modelCatalog,
  secretPath,
}:

let
  inherit (inputs.agents-nix.lib.models) channelIds;

  baseUrl = corpHosts.llmGatewayUrl;
  caSecret = "llm-assistants/corp-gateway/cachain.crt";
  portalTokenSecret = "llm-assistants/corp-gateway/portal-token";
  tokenSecretFor = client: "llm-assistants/corp-gateway/api-key/${client}";

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
  # Pricing overrides
  # ------------------------------------------------------------------------------------------------
  perToken = rate: rate / 1000000.0;

  mkPricingOverride = cost: {
    inputCostPerToken = perToken cost.input;
    outputCostPerToken = perToken cost.output;
    cacheReadInputTokenCost = perToken cost.cacheRead;
    cacheCreationInputTokenCost = perToken cost.cacheWrite;
  };

  # The offline LiteLLM snapshot is stale and prices local models at reseller rates, so override it
  # from the catalog's billed costs.
  pricingOverrides = lib.concatMapAttrs (
    _: model:
    lib.concatMapAttrs (
      channel: channelId:
      lib.genAttrs (channelIds channelId) (_: mkPricingOverride model.channelBilledCost.${channel})
    ) (model.channelId or { })
  ) modelCatalog.models;

  # ------------------------------------------------------------------------------------------------
  # Claude Code per-profile workarounds
  # ------------------------------------------------------------------------------------------------
  localMiniKey = modelCatalog.defaults.local.mini;
  localMiniModel = modelCatalog.models.${localMiniKey};
  localMiniId = localMiniModel.channelId.local;
  localMiniAliasId =
    localMiniId + lib.optionalString (localMiniModel.contextWindow >= 1000000) "[1m]";

  localDefaultModel = modelCatalog.models.${modelCatalog.defaults.local.default};

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
      smallFastId = modelCatalog.defaults.claude.mini;
    };

    corp-gateway-openai = mkClaudeProfileOverrides {
      smallFastId = modelCatalog.models.${modelCatalog.defaults.gpt.mini}.channelId.openai;
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
      smallFastId = localMiniId;
      extraEnv.CLAUDE_CODE_MAX_CONTEXT_TOKENS = toString localDefaultModel.contextWindow;
    };

    corp-gateway-hybrid = mkClaudeProfileOverrides {
      smallFastId = localMiniId;
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

  modelCallClients = [
    "claude-code"
    "codex"
    "prose-polish"
  ];
in
{
  inherit caSecret;

  providers.corp-gateway = {
    inherit baseUrl channels extraHeaders;

    apiUrls = {
      anthropic-messages = "${baseUrl}/anthropic";
      openai-responses = "${baseUrl}/v1";
    };

    clientApiKeyFiles = lib.genAttrs providerClients (client: secretPath (tokenSecretFor client));
    caCertFile = secretPath caSecret;
    extraEnv.CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
  };

  inherit claudeProfileOverrides;

  profiles = channelProfiles // {
    corp-gateway-hybrid = {
      provider = "corp-gateway";
      defaultsKey = "hybrid";
    };
  };

  modelCall = {
    enable = true;
    baseUrl = "${baseUrl}/v1";
    clientApiKeyFiles = lib.genAttrs modelCallClients (client: secretPath (tokenSecretFor client));
    caCertFile = secretPath caSecret;
    channels = builtins.attrNames channels;
    inherit extraHeaders;
  };

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

  inherit pricingOverrides;

  requiredSecrets = lib.unique (
    map tokenSecretFor (providerClients ++ modelCallClients)
    ++ [
      caSecret
      portalTokenSecret
    ]
  );
}
