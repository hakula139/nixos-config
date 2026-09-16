# ==============================================================================
# Agenix Root Entry Point
# ==============================================================================

let
  rules = import ./secrets/secrets.nix;
in
# Agenix matches rule keys to filenames relative to the working directory.
builtins.listToAttrs (
  map (name: {
    name = "secrets/${name}";
    value = rules.${name};
  }) (builtins.attrNames rules)
)
