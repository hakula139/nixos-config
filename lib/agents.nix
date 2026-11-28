# ==================================================================================================
# Agent Profile Helpers
# ==================================================================================================

{
  lib,
}:

let
  clientSpecs = {
    claude-code = {
      nativeFamily = "claude";
    };

    codex = {
      nativeFamily = "gpt";
      hasChannelFilters = true;
    };

    omp = {
      nativeFamily = "gpt";
    };

    oxide-code = {
      nativeFamily = "claude";
      anthropicOnly = true;
    };
  };

  resolvedClientProfiles =
    agents: client:
    let
      spec = clientSpecs.${client};
      auth = agents.${client}.auth;

      resolvedProfiles = agents.resolved.resolveProfiles (
        {
          inherit client;
          inherit (spec) nativeFamily;
        }
        // lib.optionalAttrs (spec.hasChannelFilters or false) {
          inherit (auth) allowedProviders allowedChannels;
        }
      );

      compatibleProfiles =
        if spec.anthropicOnly or false then
          lib.filterAttrs (_: profile: profile.roles.default.api == "anthropic-messages") resolvedProfiles
        else
          resolvedProfiles;
    in
    if auth.enabledProfiles == null then
      compatibleProfiles
    else
      lib.filterAttrs (name: _: lib.elem name auth.enabledProfiles) compatibleProfiles;

  isProfileEnabled =
    agents: client: name:
    resolvedClientProfiles agents client ? ${name};

  mkGatewayDefaultProfile =
    config: client: name:
    lib.mkIf (
      config.hakula.llm-assistants.auth.enableCorpGateway && isProfileEnabled config.agents client name
    ) (lib.mkDefault name);
in
{
  inherit
    isProfileEnabled
    mkGatewayDefaultProfile
    ;
}
