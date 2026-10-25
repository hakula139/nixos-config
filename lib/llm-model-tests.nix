# ==================================================================================================
# LLM Model Tests
# ==================================================================================================

{
  pkgs,
  modelCatalog,
}:

let
  inherit (pkgs) lib;

  gptEfforts = [
    "low"
    "medium"
    "high"
    "xhigh"
    "max"
  ];

  chatEfforts = [
    "low"
    "medium"
    "high"
    "xhigh"
  ];

  invalidCapabilities = lib.filterAttrs (
    _: model:
    let
      thinking = model.thinking or null;
      apiEfforts = if thinking == null then { } else thinking.apiEfforts or { };
    in
    model.apis == [ ]
    || lib.any (
      api:
      !(lib.elem api [
        "anthropic-messages"
        "openai-chat-completions"
        "openai-responses"
      ])
    ) model.apis
    || lib.any (api: !(lib.elem api model.apis)) (builtins.attrNames apiEfforts)
    || (
      thinking != null
      && lib.any (
        api:
        !(builtins.hasAttr api apiEfforts)
        || lib.any (effort: !(lib.elem effort thinking.efforts)) apiEfforts.${api}
        || (thinking.requiresEffort && !(lib.elem thinking.defaultLevel apiEfforts.${api}))
      ) model.apis
    )
  ) modelCatalog.models;

  profileDefinitions = import ./llm-assistants/profiles.nix {
    inherit lib modelCatalog;
    corpHosts.llmGatewayUrl = "https://example.com";
  };

  profiles = profileDefinitions.mkProfiles {
    nativeFamily = "gpt";
    providers = [ "corp-gateway" ];
    channels = [ "openai" ];
    enableCorpGateway = true;
  };

  workloads =
    profile:
    lib.mapAttrs (_: workload: {
      inherit (workload) api modelKey effort;
      inherit (workload.model.thinking) efforts;
    }) profile.workloads;

  expectedWorkloads = {
    flagship = {
      api = "openai-responses";
      modelKey = "gpt-6.1-sol";
      effort = "xhigh";
      efforts = gptEfforts;
    };

    standard = {
      api = "openai-responses";
      modelKey = "gpt-6.1-sol";
      effort = "medium";
      efforts = gptEfforts;
    };

    mini = {
      api = "openai-responses";
      modelKey = "gpt-6-luna";
      effort = "low";
      efforts = gptEfforts;
    };
  };

  failures = lib.runTests {
    testDeclaredApisAcceptOnlyDeclaredEffortsAndRequiredDefaults = {
      expr = builtins.attrNames invalidCapabilities;
      expected = [ ];
    };

    testChatAndResponsesKeepTheirDifferentEffortCapabilities = {
      expr = map (name: modelCatalog.models.${name}.thinking.apiEfforts) [
        "gpt-6-astra"
        "gpt-6.1-sol"
      ];
      expected = lib.replicate 2 {
        openai-chat-completions = chatEfforts;
        openai-responses = gptEfforts;
      };
    };

    testNativeMessagesUsesAdaptiveThinkingWithItsDeclaredEfforts = {
      expr = {
        inherit (modelCatalog.models.claude-opus-5-5) apis;
        inherit (modelCatalog.models.claude-opus-5-5.thinking) mode apiEfforts;
      };
      expected = {
        apis = [ "anthropic-messages" ];
        mode = "anthropic-adaptive";
        apiEfforts = {
          anthropic-messages = gptEfforts;
        };
      };
    };

    testNativeAndResponsesModelsKeepMaximumEffort = {
      expr = map (name: modelCatalog.models.${name}.thinking.efforts) [
        "gpt-6-astra"
        "gpt-6.1-sol"
        "gpt-6-luna"
      ];
      expected = [
        gptEfforts
        gptEfforts
        gptEfforts
      ];
    };

    testLunaKeepsItsProvenApiAndDefaultEffort = {
      expr = {
        inherit (modelCatalog.models.gpt-6-luna) apis;
        inherit (modelCatalog.models.gpt-6-luna.thinking) apiEfforts defaultLevel;
      };
      expected = {
        apis = [ "openai-responses" ];
        apiEfforts.openai-responses = gptEfforts;
        defaultLevel = "low";
      };
    };

    testOfficialClientWorkloadsKeepTheirNativeCapabilities = {
      expr = workloads profiles.official;
      expected = expectedWorkloads;
    };

    testGatewayClientWorkloadsKeepTheirNativeCapabilities = {
      expr = workloads profiles.corp-gateway-openai;
      expected = expectedWorkloads;
    };
  };
in
assert lib.assertMsg (failures == [ ]) (builtins.toJSON failures);
pkgs.runCommand "llm-model-tests" { } ''
  touch "$out"
''
