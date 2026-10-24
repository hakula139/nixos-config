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

  apiRestrictions = lib.mapAttrs (_: model: model.thinking.apiEfforts) (
    lib.filterAttrs (_: model: (model.thinking.apiEfforts or { }) != { }) modelCatalog.models
  );

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
    testChatRestrictionsStayWithinTheProbedModels = {
      expr = apiRestrictions;
      expected = {
        "gpt-6-astra".openai-chat-completions = chatEfforts;
        "gpt-6.1-sol".openai-chat-completions = chatEfforts;
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

    testLunaKeepsItsDefaultEffort = {
      expr = modelCatalog.models.gpt-6-luna.thinking.defaultLevel;
      expected = "low";
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
