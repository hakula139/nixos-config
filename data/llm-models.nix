# ==================================================================================================
# LLM Gateway Model Policy
# ==================================================================================================

let
  # ------------------------------------------------------------------------------------------------
  # Local model capabilities
  # ------------------------------------------------------------------------------------------------
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

      hydrogen = {
        input = 1.5;
        output = 7.5;
        cacheRead = 0.075;
        cacheWrite = 0.0833333333333333;
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
in
{
  # ------------------------------------------------------------------------------------------------
  # Defaults
  # ------------------------------------------------------------------------------------------------
  local = {
    default = "kimi-k3.1-pro";
    flagship = "kimi-k3.1-pro";
    standard = "kimi-k3.1-pro";
    mini = "deepseek-v4.1-flash";
  };

  # ------------------------------------------------------------------------------------------------
  # Models
  # ------------------------------------------------------------------------------------------------
  models = builtins.mapAttrs (_: withBilledCost) {
    # ----------------------------------------------------------------------------------------------
    # Claude
    # ----------------------------------------------------------------------------------------------
    "claude-opus-5-5" = {
      channelId.anthropic = "azure/claude-opus-5-5";
      channelCost.anthropic = costs.claude.opus;
    };

    "claude-sonnet-5-5" = {
      channelId.anthropic = "bedrock/global.anthropic.claude-sonnet-5-5";
      channelCost.anthropic = costs.claude.sonnet;
    };

    "claude-haiku-5-5" = {
      channelId.anthropic = "bedrock/global.anthropic.claude-haiku-5-5";
      channelCost.anthropic = costs.claude.haiku;
    };

    # ----------------------------------------------------------------------------------------------
    # GPT
    # ----------------------------------------------------------------------------------------------
    "gpt-6.2-astra" = {
      channelId.openai = "azure/gpt-6.2-astra";
      channelCost.openai = costs.gpt.astra-6-2;
    };

    "gpt-6.2-sol" = {
      channelId.openai = "azure/gpt-6.2-sol";
      channelCost.openai = costs.gpt.sol;
    };

    "gpt-6.1-terra" = {
      channelId.openai = "azure/gpt-6.1-terra";
      channelCost.openai = costs.gpt.terra;
    };

    "gpt-6-luna" = {
      channelId.openai = "azure/gpt-6-luna";
      channelCost.openai = costs.gpt.luna;
    };

    # ----------------------------------------------------------------------------------------------
    # Gemini
    # ----------------------------------------------------------------------------------------------
    "gemini-4-carbon" = {
      channelId.google = "openrouter/google/gemini-4-carbon";
      channelCost.google = costs.gemini.carbon;
    };

    "gemini-4-neon" = {
      channelId.google = "gemini/gemini-4-neon";
      channelCost.google = costs.gemini.neon;
    };

    "gemini-4-hydrogen" = {
      channelId.google = "gemini/gemini-4-hydrogen";
      channelCost.google = costs.gemini.hydrogen;
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
