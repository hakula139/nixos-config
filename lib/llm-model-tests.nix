# ==================================================================================================
# LLM Model Tests
# ==================================================================================================

{
  pkgs,
  modelCatalog,
}:

let
  inherit (pkgs) lib;

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
        || !(lib.elem thinking.defaultLevel apiEfforts.${api})
      ) model.apis
    )
  ) modelCatalog.models;

  profileDefinitions = import ./llm-assistants/profiles.nix {
    inherit lib modelCatalog;
    corpHosts.llmGatewayUrl = "https://example.com";
  };

  maintainedProfiles = lib.concatMap (
    family:
    builtins.attrValues (
      profileDefinitions.mkProfiles {
        nativeFamily = family;
        hybridBase = "corp-gateway-openai";
        providers = [
          "corp-gateway"
          "ikuncode"
          "yescode"
        ];
        channels = [
          "anthropic"
          "openai"
          "google"
          "local"
        ];
        enableCorpGateway = true;
      }
    )
  ) (builtins.attrNames profileDefinitions.workloadPolicy);

  invalidWorkloads = lib.concatMap (
    profile:
    lib.filter (
      workload:
      !(lib.elem workload.api workload.model.apis)
      || !(lib.elem workload.effort (workload.model.thinking.apiEfforts.${workload.api} or [ ]))
    ) (builtins.attrValues profile.workloads ++ builtins.attrValues profile.roles)
  ) maintainedProfiles;

  failures = lib.runTests {
    testDeclaredApisAcceptOnlyDeclaredEffortsAndDefaults = {
      expr = builtins.attrNames invalidCapabilities;
      expected = [ ];
    };

    testMaintainedClientWorkloadsAndRolesUseAdmittedApisAndEfforts = {
      expr = lib.unique (map (workload: { inherit (workload) modelKey api effort; }) invalidWorkloads);
      expected = [ ];
    };
  };
in
assert lib.assertMsg (failures == [ ]) (builtins.toJSON failures);
pkgs.runCommand "llm-model-tests" { } ''
  touch "$out"
''
