# ==============================================================================
# Agenix Root Entry Point
# ==============================================================================

let
  rules = import ./secrets/agenix-rules.nix;
in
# Agenix resolves secret paths relative to the selected rules file.
builtins.listToAttrs (
  map (name: {
    name = "secrets/${name}";
    value = rules.${name};
  }) (builtins.attrNames rules)
)
