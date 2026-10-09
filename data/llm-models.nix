# ==============================================================================
# LLM Model Catalog
# ==============================================================================

let
  claudeAdaptiveCommon = {
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
      supportsDisplay = true;
    };
  };

  gptCommon = {
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
    };
  };

  geminiCommon = {
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
      requiresEffort = true;
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
      flagship = "gpt-6-astra";
      standard = "gpt-6.1-sol";
      mini = "gpt-6-luna";
    };
    gemini = {
      flagship = "gemini-4-argon";
      standard = "gemini-4-argon";
      mini = "gemini-3.8-flash";
    };
    local = {
      flagship = "kimi-k3";
      standard = "kimi-k3";
      mini = "glm-5.3-flash";
    };
  };

  # Gateway costs are USD per million tokens.
  models = {
    "claude-opus-5-5" = claudeAdaptiveCommon // {
      name = "Claude Opus 5.5";
      thinking = claudeAdaptiveCommon.thinking // {
        defaultLevel = "high";
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

    # Claude Code's auto-mode classifier requests this model regardless of the tier aliases.
    "claude-sonnet-5" = claudeAdaptiveCommon // {
      name = "Claude Sonnet 5";
      channelId.anthropic = "bedrock/global.anthropic.claude-sonnet-5";
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

    "claude-haiku-4-5-20251001" = {
      name = "Claude Haiku 4.5";
      contextWindow = 200000;
      maxTokens = 64000;
      autoCompactTokens = 160000;
      input = [
        "text"
        "image"
      ];
      reasoning = true;
      thinking = {
        mode = "budget";
        efforts = [
          "minimal"
          "low"
          "medium"
          "high"
          "xhigh"
        ];
        defaultLevel = "high";
      };
      channelId.anthropic = "bedrock/global.anthropic.claude-haiku-4-5-20251001-v1:0";
      channelCost.anthropic = {
        input = 1.0;
        output = 5.0;
        cacheRead = 0.1;
        cacheWrite = 1.25;
      };
    };

    "gpt-6-astra" = gptCommon // {
      name = "GPT-6 Astra";
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
      maxTokens = 1000000;
      # Argon's routing ID, reasoning levels and cache-write cost await OpenRouter metadata.
      channelId.google = "openrouter/google/gemini-4-argon";
      channelCost.google = {
        input = 2.0;
        output = 10.0;
        cacheRead = 0.1;
        cacheWrite = 0;
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

    "kimi-k3" = localCommon // {
      name = "Kimi K3";
      contextWindow = 400000;
      maxTokens = 65536;
      autoCompactTokens = 320000;
      channelId.local = "Kimi-K3";
    };

    "glm-5.3" = localCommon // {
      name = "GLM-5.3";
      contextWindow = 400000;
      maxTokens = 131072;
      autoCompactTokens = 320000;
      input = [ "text" ];
      channelId.local = "GLM-5.3";
    };

    "glm-5.3-flash" = localCommon // {
      name = "GLM-5.3-Flash";
      contextWindow = 1048576;
      maxTokens = 131072;
      autoCompactTokens = 400000;
      thinking = localCommon.thinking // {
        defaultLevel = "low";
      };
      channelId.local = "GLM-5.3-Flash";
    };
  };
}
