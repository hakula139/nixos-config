{ lib }:

# ==============================================================================
# Shared Agent Role Options
# ==============================================================================

let
  sharedAgentNames = builtins.attrNames (import ./default.nix);
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
