# ==============================================================================
# OMP Model Configuration
# ==============================================================================

{
  pkgs,
  lib,
  corpHosts,
  modelCatalog,
  secretPath,
  enableCorpGateway,
}:

let
  profiles = lib.optionalAttrs enableCorpGateway {
    corp-gateway-bedrock = {
      api = "anthropic-messages";
      baseUrl = "${corpHosts.llmGatewayUrl}/anthropic";
      gateway = "bedrock";
      modelIds = builtins.attrValues modelCatalog.defaults.claude;
    };
    corp-gateway-openai = {
      api = "openai-responses";
      baseUrl = "${corpHosts.llmGatewayUrl}/v1";
      gateway = "openai";
      modelIds = builtins.attrValues modelCatalog.defaults.gpt;
    };
  };

  tokenSecret = "llm-assistants/bifrost-api-key";

  mkModel =
    gateway: modelId:
    let
      model = modelCatalog.models.${modelId};
      id = model.gatewayId.${gateway};
    in
    {
      inherit id;
      inherit (model)
        name
        contextWindow
        maxTokens
        reasoning
        thinking
        ;
      cost = model.gatewayCost.${gateway};
      input = [
        "text"
        "image"
      ];
    };

  mkProvider = _: profile: {
    inherit (profile) api baseUrl;
    auth = "apiKey";
    apiKey = "!${lib.getExe' pkgs.coreutils "cat"} ${lib.escapeShellArg (secretPath tokenSecret)}";
    authHeader = true;
    models = map (mkModel profile.gateway) (lib.unique profile.modelIds);
  };
in
{
  providers = lib.mapAttrs mkProvider profiles;
  requiredSecrets = lib.optionalAttrs enableCorpGateway (
    lib.genAttrs [ tokenSecret "llm-assistants/corp-cachain.crt" ] (_: { })
  );
}
