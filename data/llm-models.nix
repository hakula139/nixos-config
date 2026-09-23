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
      defaultLevel = "high";
      supportsDisplay = true;
    };
  };

  geminiCommon = {
    contextWindow = 1048576;
    maxTokens = 65536;
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
    gatewayCost.local = {
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
      # Use Sonnet for lightweight coding tasks because Haiku falls below our quality baseline.
      mini = "claude-sonnet-5";
    };
    gemini = {
      flagship = "gemini-3.1-pro-preview";
      standard = "gemini-3.8-flash";
    };
    gpt = {
      flagship = "gpt-6-astra";
      standard = "gpt-6-sol";
      mini = "gpt-6-luna";
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
        defaultLevel = "medium";
        requiresEffort = true;
      };
      gatewayId.bedrock = "bedrock/anthropic.claude-opus-5-5";
      gatewayCost.bedrock = {
        input = 4.0;
        output = 20.0;
        cacheRead = 0.2;
        cacheWrite = 5.0;
      };
    };

    "claude-sonnet-5" = claudeAdaptiveCommon // {
      name = "Claude Sonnet 5";
      thinking = claudeAdaptiveCommon.thinking // {
        defaultLevel = "low";
      };
      gatewayId.bedrock = "bedrock/global.anthropic.claude-sonnet-5";
      gatewayCost.bedrock = {
        input = 2.0;
        output = 10.0;
        cacheRead = 0.2;
        cacheWrite = 2.5;
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
      gatewayId.bedrock = "bedrock/global.anthropic.claude-haiku-4-5-20251001-v1:0";
      gatewayCost.bedrock = {
        input = 1.0;
        output = 5.0;
        cacheRead = 0.1;
        cacheWrite = 1.25;
      };
    };

    "gemini-3.1-pro-preview" = geminiCommon // {
      name = "Gemini 3.1 Pro Preview";
      gatewayId.openrouter = "openrouter/google/gemini-3.1-pro-preview";
      gatewayCost.openrouter = {
        input = 2.0;
        output = 12.0;
        cacheRead = 0.2;
        cacheWrite = 0.375;
      };
    };

    "gemini-3.8-flash" = geminiCommon // {
      name = "Gemini 3.8 Flash";
      gatewayId.openrouter = "openrouter/google/gemini-3.8-flash";
      gatewayCost.openrouter = {
        input = 0.75;
        output = 3.75;
        cacheRead = 0.075;
        cacheWrite = 0.0416666666666667;
      };
    };

    "gpt-6-astra" = gptCommon // {
      name = "GPT-6 Astra";
      gatewayId.openai = "openai/gpt-6-astra";
      gatewayCost.openai = {
        input = 10.0;
        output = 50.0;
        cacheRead = 1.0;
        cacheWrite = 12.5;
      };
    };

    "gpt-6-sol" = gptCommon // {
      name = "GPT-6 Sol";
      gatewayId.openai = "openai/gpt-6-sol";
      gatewayCost.openai = {
        input = 2.0;
        output = 10.0;
        cacheRead = 0.2;
        cacheWrite = 2.5;
      };
    };

    "gpt-6-luna" = gptCommon // {
      name = "GPT-6 Luna";
      thinking = gptCommon.thinking // {
        defaultLevel = "low";
      };
      gatewayId.openai = "openai/gpt-6-luna";
      gatewayCost.openai = {
        input = 0.1;
        output = 0.5;
        cacheRead = 0.01;
        cacheWrite = 0.125;
      };
    };

    "kimi-k3" = localCommon // {
      name = "Kimi K3";
      contextWindow = 400000;
      maxTokens = 65536;
      autoCompactTokens = 320000;
      gatewayId.local = "Kimi-K3";
    };

    "glm-5.3" = localCommon // {
      name = "GLM-5.3";
      contextWindow = 400000;
      maxTokens = 131072;
      autoCompactTokens = 320000;
      input = [ "text" ];
      gatewayId.local = "GLM-5.3";
    };

    "glm-5.3-flash" = localCommon // {
      name = "GLM-5.3-Flash";
      contextWindow = 1048576;
      maxTokens = 131072;
      autoCompactTokens = 400000;
      thinking = localCommon.thinking // {
        defaultLevel = "low";
      };
      gatewayId.local = "GLM-5.3-Flash";
    };
  };
}
