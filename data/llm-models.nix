# ==============================================================================
# LLM Model Catalog
# ==============================================================================

let
  claudeAdaptiveCommon = {
    autoCompactTokens = 400000;
    contextWindow = 1000000;
    maxTokens = 128000;
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
    autoCompactTokens = 250000;
    contextWindow = 1050000;
    maxTokens = 128000;
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
      defaultLevel = "medium";
    };
  };
in
{
  defaults = {
    claude = {
      flagship = "claude-opus-5";
      standard = "claude-sonnet-5";
      # Use Sonnet for lightweight coding tasks because Haiku falls below our quality baseline.
      mini = "claude-sonnet-5";
    };
    gemini = {
      flagship = "gemini-3.1-pro-preview";
      standard = "gemini-3.8-flash";
    };
    gpt = {
      flagship = "gpt-6-astra";
      standard = "gpt-5.6-terra";
      mini = "gpt-5.6-luna";
    };
  };

  # Gateway costs are USD per million tokens.
  models = {
    "claude-opus-5" = claudeAdaptiveCommon // {
      name = "Claude Opus 5";
      gatewayId.bedrock = "bedrock/global.anthropic.claude-opus-5";
      gatewayCost.bedrock = {
        input = 5.0;
        output = 25.0;
        cacheRead = 0.5;
        cacheWrite = 6.25;
      };
    };

    "claude-sonnet-5" = claudeAdaptiveCommon // {
      name = "Claude Sonnet 5";
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
      autoCompactTokens = 160000;
      contextWindow = 200000;
      maxTokens = 64000;
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

    "gpt-5.6-terra" = gptCommon // {
      name = "GPT-5.6 Terra";
      gatewayId.openai = "openai/gpt-5.6-terra";
      gatewayCost.openai = {
        input = 2.0;
        output = 12.0;
        cacheRead = 0.2;
        cacheWrite = 2.5;
      };
    };

    "gpt-5.6-luna" = gptCommon // {
      name = "GPT-5.6 Luna";
      gatewayId.openai = "openai/gpt-5.6-luna";
      gatewayCost.openai = {
        input = 0.2;
        output = 1.2;
        cacheRead = 0.02;
        cacheWrite = 0.25;
      };
    };
  };
}
