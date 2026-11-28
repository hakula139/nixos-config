# ==================================================================================================
# Agent Profile Helpers
# ==================================================================================================

{
  lib,
}:

{
  mkGatewayDefaultProfile =
    config: client: name:
    lib.mkIf (
      config.hakula.llm-assistants.auth.enableCorpGateway
      && config.agents.resolved.clientProfiles.${client} ? ${name}
    ) (lib.mkDefault name);
}
