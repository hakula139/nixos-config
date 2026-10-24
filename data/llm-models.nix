# ==================================================================================================
# LLM Model Catalog
# ==================================================================================================

let
  claudeAdaptiveCommon = {
    vendor = "anthropic";
    contextWindow = 1000000;
    maxTokens = 128000;
    autoCompactTokens = 400000;
    input = [
      "text"
      "image"
    ];

    reasoning = true;
    thinking = {
      mode = "anthropic-adaptive";
      efforts = [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];

      defaultLevel = "medium";
      requiresEffort = false;
      supportsDisplay = true;
    };
  };

  gptCommon = {
    vendor = "openai";
    contextWindow = 1050000;
    maxTokens = 128000;
    autoCompactTokens = 272000;
    input = [
      "text"
      "image"
    ];

    reasoning = true;
    thinking = {
      mode = "effort";
      efforts = [
        "low"
        "medium"
        "high"
        "xhigh"
        "max"
      ];

      defaultLevel = "high";
      requiresEffort = false;
      supportsDisplay = false;
    };
  };

  gptChatEfforts = [
    "low"
    "medium"
    "high"
    "xhigh"
  ];

  geminiCommon = {
    vendor = "google";
    contextWindow = 1048576;
    maxTokens = 65536;
    autoCompactTokens = 400000;
    input = [
      "text"
      "image"
    ];

    reasoning = true;
    thinking = {
      mode = "effort";
      efforts = [
        "low"
        "medium"
        "high"
      ];

      defaultLevel = "medium";
      requiresEffort = true;
      supportsDisplay = false;
    };
  };

  localCommon = {
    input = [
      "text"
      "image"
    ];

    reasoning = true;
    thinking = {
      mode = "effort";
      efforts = [
        "low"
        "high"
        "max"
      ];

      defaultLevel = "high";
      requiresEffort = false;
      supportsDisplay = false;
    };

    channelCost.local = {
      input = 0;
      output = 0;
      cacheRead = 0;
      cacheWrite = 0;
    };
  };
in
{
  defaults = {
    claude = {
      flagship = "claude-opus-5-5";
      standard = "claude-opus-5-5";
      mini = "claude-haiku-5-5";
    };

    gpt = {
      flagship = "gpt-6.1-sol";
      standard = "gpt-6.1-sol";
      mini = "gpt-6-luna";
    };

    gemini = {
      flagship = "gemini-4-argon";
      standard = "gemini-4-argon";
      mini = "gemini-3.8-flash";
    };

    local = {
      flagship = "deepseek-v4.1-flash";
      standard = "deepseek-v4.1-flash";
      mini = "deepseek-v4.1-flash";
    };
  };

  # Gateway costs are USD per million tokens.
  models = {
    "claude-opus-5-5" = claudeAdaptiveCommon // {
      name = "Claude Opus 5.5";
      thinking = claudeAdaptiveCommon.thinking // {
        requiresEffort = true;
      };

      channelId.anthropic = "bedrock/global.anthropic.claude-opus-5-5";
      channelCost.anthropic = {
        input = 4.0;
        output = 20.0;
        cacheRead = 0.2;
        cacheWrite = 5.0;
      };
    };

    "claude-sonnet-5-5" = claudeAdaptiveCommon // {
      name = "Claude Sonnet 5.5";
      channelId.anthropic = "bedrock/global.anthropic.claude-sonnet-5-5";
      channelCost.anthropic = {
        input = 2.2;
        output = 11.0;
        cacheRead = 0.22;
        cacheWrite = 2.75;
      };
    };

    # Claude Code's auto-mode classifier requests this model regardless of the tier aliases. The
    # gateway's global inference profile for it returns 503, so it routes through the US profile.
    "claude-sonnet-5" = claudeAdaptiveCommon // {
      name = "Claude Sonnet 5";
      channelId.anthropic = "bedrock/us.anthropic.claude-sonnet-5";
      channelCost.anthropic = {
        input = 2.0;
        output = 10.0;
        cacheRead = 0.2;
        cacheWrite = 2.5;
      };
    };

    # Prompts over 100k tokens cost 5x these base rates.
    "claude-haiku-5-5" = claudeAdaptiveCommon // {
      name = "Claude Haiku 5.5";
      channelId.anthropic = "bedrock/global.anthropic.claude-haiku-5-5";
      channelCost.anthropic = {
        input = 0.1;
        output = 0.5;
        cacheRead = 0.01;
        cacheWrite = 0.125;
      };
    };

    "gpt-6-astra" = gptCommon // {
      name = "GPT-6 Astra";
      thinking = gptCommon.thinking // {
        apiEfforts.openai-chat-completions = gptChatEfforts;
      };

      channelId.openai = "openai/gpt-6-astra";
      channelCost.openai = {
        input = 10.0;
        output = 50.0;
        cacheRead = 1.0;
        cacheWrite = 12.5;
      };
    };

    "gpt-6.1-sol" = gptCommon // {
      name = "GPT-6.1 Sol";
      thinking = gptCommon.thinking // {
        apiEfforts.openai-chat-completions = gptChatEfforts;
      };

      channelId.openai = "openai/gpt-6.1-sol";
      channelCost.openai = {
        input = 2.0;
        output = 10.0;
        cacheRead = 0.1;
        cacheWrite = 2.5;
      };
    };

    "gpt-6-luna" = gptCommon // {
      name = "GPT-6 Luna";
      thinking = gptCommon.thinking // {
        defaultLevel = "low";
      };

      channelId.openai = "openai/gpt-6-luna";
      channelCost.openai = {
        input = 0.1;
        output = 0.5;
        cacheRead = 0.01;
        cacheWrite = 0.125;
      };
    };

    "gemini-4-argon" = geminiCommon // {
      name = "Gemini 4 Argon";
      channelId.google = "openrouter/google/gemini-4-argon";
      channelCost.google = {
        input = 2.0;
        output = 10.0;
        cacheRead = 0.1;
        cacheWrite = 0.1875;
      };
    };

    "gemini-3.8-flash" = geminiCommon // {
      name = "Gemini 3.8 Flash";
      channelId.google = "openrouter/google/gemini-3.8-flash";
      channelCost.google = {
        input = 0.75;
        output = 3.75;
        cacheRead = 0.075;
        cacheWrite = 0.0416666666666667;
      };
    };

    "deepseek-v4.1-flash" = localCommon // {
      name = "DeepSeek V4.1 Flash 1017";
      vendor = "deepseek";
      contextWindow = 1048576;
      maxTokens = 393216;
      autoCompactTokens = 400000;
      channelId.local = "local_v2/DeepSeek-V4.1-Flash-1017";
    };

    "kimi-k3" = localCommon // {
      name = "Kimi K3";
      vendor = "moonshot";
      contextWindow = 409600;
      maxTokens = 65536;
      autoCompactTokens = 320000;
      channelId.local = "local_v2_k3/Kimi-K3";
    };
  };
}
