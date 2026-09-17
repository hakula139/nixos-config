# ==============================================================================
# Shared Agent Role Options
# ==============================================================================

{
  lib,
  agentRoles,
}:

let
  sharedAgentNames = builtins.attrNames agentRoles;
in
{
  inherit sharedAgentNames;

  mkEnabledAgentsOption =
    {
      description,
      names ? sharedAgentNames,
      default ? names,
    }:
    lib.mkOption {
      type = lib.types.listOf (lib.types.enum names);
      inherit default description;
    };
}
