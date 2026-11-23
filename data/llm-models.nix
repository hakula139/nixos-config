# ==================================================================================================
# LLM Model Catalog
# ==================================================================================================

let
  # ------------------------------------------------------------------------------------------------
  # Family capabilities
  # ------------------------------------------------------------------------------------------------
  claudeCommon = {
    vendor = "anthropic";
    apis = [ "anthropic-messages" ];

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
    };
  };

  gptCommon = {
    vendor = "openai";
    apis = [ "openai-responses" ];

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
    vendor = "google";
    apis = [
      "openai-chat-completions"
      "openai-responses"
    ];

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
    };
  };

  localCommon = {
    apis = [
      "openai-chat-completions"
      "openai-responses"
    ];

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
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Gateway costs
  # ------------------------------------------------------------------------------------------------
  # USD per million tokens.
  costs = {
    claude = {
      opus = {
        input = 4.0;
        output = 20.0;
        cacheRead = 0.2;
        cacheWrite = 5.0;
      };

      sonnet = {
        input = 2.0;
        output = 10.0;
        cacheRead = 0.1;
        cacheWrite = 2.5;
      };

      # Prompts over 100k tokens cost 5x these base rates.
      haiku = {
        input = 0.1;
        output = 0.5;
        cacheRead = 0.01;
        cacheWrite = 0.125;
      };
    };

    gpt = {
      astra-6-2 = {
        input = 8.0;
        output = 40.0;
        cacheRead = 0.4;
        cacheWrite = 10.0;
      };

      astra-6 = {
        input = 10.0;
        output = 50.0;
        cacheRead = 1.0;
        cacheWrite = 12.5;
      };

      sol = {
        input = 2.0;
        output = 10.0;
        cacheRead = 0.1;
        cacheWrite = 2.5;
      };

      terra = {
        input = 1.0;
        output = 5.0;
        cacheRead = 0.05;
        cacheWrite = 1.25;
      };

      luna = {
        input = 0.1;
        output = 0.5;
        cacheRead = 0.01;
        cacheWrite = 0.125;
      };
    };

    gemini = {
      # Introductory price through 2026-11-30, then $4 input, $20 output, and $0.20 cache read.
      carbon = {
        input = 2.0;
        output = 10.0;
        cacheRead = 0.1;
        cacheWrite = 0.1875;
      };

      neon = {
        input = 3.0;
        output = 15.0;
        cacheRead = 0.15;
        cacheWrite = 0.0833333333333333;
      };

      # Same introductory price and 2026-12-01 step as Carbon.
      argon = {
        input = 2.0;
        output = 10.0;
        cacheRead = 0.1;
        cacheWrite = 0.1875;
      };

      hydrogen = {
        input = 1.5;
        output = 7.5;
        cacheRead = 0.075;
        cacheWrite = 0.0833333333333333;
      };

      flash = {
        input = 0.75;
        output = 3.75;
        cacheRead = 0.075;
        cacheWrite = 0.0416666666666667;
      };
    };

    local = {
      kimi = {
        input = 2.0;
        output = 10.0;
        cacheRead = 0.2;
        cacheWrite = 0;
      };

      deepseek = {
        input = 0.15;
        output = 0.60;
        cacheRead = 0.003;
        cacheWrite = 0.15;
      };
    };

    free = {
      input = 0;
      output = 0;
      cacheRead = 0;
      cacheWrite = 0;
    };
  };

  # Local gateway endpoints bill $0 at runtime, while `channelCost` keeps their reference rates for
  # benchmark accounting.
  freeChannels = [ "local" ];

  withBilledCost =
    model:
    model
    // {
      channelBilledCost = builtins.mapAttrs (
        channel: cost: if builtins.elem channel freeChannels then costs.free else cost
      ) model.channelCost;
    };

  # ------------------------------------------------------------------------------------------------
  # Tier defaults
  # ------------------------------------------------------------------------------------------------
  familyDefaults = {
    claude = {
      default = "claude-opus-5-5";
      flagship = "claude-opus-5-5";
      standard = "claude-sonnet-5-5";
      mini = "claude-haiku-5-5";
    };

    gpt = {
      default = "gpt-6.2-sol";
      flagship = "gpt-6.2-astra";
      standard = "gpt-6.2-sol";
      mini = "gpt-6-luna";
    };

    gemini = {
      default = "gemini-4-neon";
      flagship = "gemini-4-carbon";
      standard = "gemini-4-neon";
      mini = "gemini-4-hydrogen";
    };

    local = {
      default = "kimi-k3.1-pro";
      flagship = "kimi-k3.1-pro";
      standard = "kimi-k3.1-pro";
      mini = "deepseek-v4.1-flash";
    };
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Defaults
  # ------------------------------------------------------------------------------------------------
  defaults = familyDefaults // {
    hybrid = {
      inherit (familyDefaults.gemini) default flagship standard;
      inherit (familyDefaults.local) mini;
    };

    prose = "gemini-4-carbon";
  };

  # ------------------------------------------------------------------------------------------------
  # Models
  # ------------------------------------------------------------------------------------------------
  models = builtins.mapAttrs (_: withBilledCost) {
    # ----------------------------------------------------------------------------------------------
    # Claude
    # ----------------------------------------------------------------------------------------------
    "claude-opus-5-5" = claudeCommon // {
      name = "Claude Opus 5.5";
      channelId.anthropic = "bedrock/global.anthropic.claude-opus-5-5";
      channelCost.anthropic = costs.claude.opus;
    };

    "claude-sonnet-5-5" = claudeCommon // {
      name = "Claude Sonnet 5.5";
      channelId.anthropic = "bedrock/global.anthropic.claude-sonnet-5-5";
      channelCost.anthropic = costs.claude.sonnet;
    };

    "claude-haiku-5-5" = claudeCommon // {
      name = "Claude Haiku 5.5";
      channelId.anthropic = "bedrock/global.anthropic.claude-haiku-5-5";
      channelCost.anthropic = costs.claude.haiku;
    };

    # ----------------------------------------------------------------------------------------------
    # GPT
    # ----------------------------------------------------------------------------------------------
    "gpt-6.2-astra" = gptCommon // {
      name = "GPT-6.2 Astra";
      channelId.openai = "openai/gpt-6.2-astra";
      channelCost.openai = costs.gpt.astra-6-2;
    };

    "gpt-6.2-sol" = gptCommon // {
      name = "GPT-6.2 Sol";
      channelId.openai = "openai/gpt-6.2-sol";
      channelCost.openai = costs.gpt.sol;
    };

    "gpt-6.1-sol" = gptCommon // {
      name = "GPT-6.1 Sol";
      channelId.openai = "openai/gpt-6.1-sol";
      channelCost.openai = costs.gpt.sol;
    };

    "gpt-6.1-terra" = gptCommon // {
      name = "GPT-6.1 Terra";
      contextWindow = 922000;
      channelId.openai = "openai/gpt-6.1-terra";
      channelCost.openai = costs.gpt.terra;
    };

    "gpt-6-astra" = gptCommon // {
      name = "GPT-6 Astra";
      channelId.openai = "openai/gpt-6-astra";
      channelCost.openai = costs.gpt.astra-6;
    };

    "gpt-6-luna" = gptCommon // {
      name = "GPT-6 Luna";

      thinking = gptCommon.thinking // {
        defaultLevel = "low";
      };

      channelId.openai = "openai/gpt-6-luna";
      channelCost.openai = costs.gpt.luna;
    };

    # ----------------------------------------------------------------------------------------------
    # Gemini
    # ----------------------------------------------------------------------------------------------
    "gemini-4-carbon" = geminiCommon // {
      name = "Gemini 4 Carbon";
      channelId.google = "openrouter/google/gemini-4-carbon";
      channelCost.google = costs.gemini.carbon;
    };

    "gemini-4-neon" = geminiCommon // {
      name = "Gemini 4 Neon";
      channelId.google = "openrouter/google/gemini-4-neon";
      channelCost.google = costs.gemini.neon;
    };

    "gemini-4-argon" = geminiCommon // {
      name = "Gemini 4 Argon";
      channelId.google = "openrouter/google/gemini-4-argon";
      channelCost.google = costs.gemini.argon;
    };

    "gemini-4-hydrogen" = geminiCommon // {
      name = "Gemini 4 Hydrogen";
      channelId.google = "openrouter/google/gemini-4-hydrogen";
      channelCost.google = costs.gemini.hydrogen;
    };

    "gemini-3.8-flash" = geminiCommon // {
      name = "Gemini 3.8 Flash";
      channelId.google = "openrouter/google/gemini-3.8-flash";
      channelCost.google = costs.gemini.flash;
    };

    # ----------------------------------------------------------------------------------------------
    # Local
    # ----------------------------------------------------------------------------------------------
    "kimi-k3.1-pro" = localCommon // {
      name = "Kimi K3.1 Pro";
      vendor = "moonshot";

      contextWindow = 409600;
      maxTokens = 131072;
      autoCompactTokens = 320000;

      channelId.local = "local_v2/Kimi-K3.1-Pro";
      channelCost.local = costs.local.kimi;
    };

    "deepseek-v4.1-flash" = localCommon // {
      name = "DeepSeek V4.1 Flash 1017";
      vendor = "deepseek";

      contextWindow = 1048576;
      maxTokens = 393216;
      autoCompactTokens = 400000;

      channelId.local = "local_v2/DeepSeek-V4.1-Flash-1017";
      channelCost.local = costs.local.deepseek;
    };
  };
}
