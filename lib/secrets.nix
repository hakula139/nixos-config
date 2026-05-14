# ==============================================================================
# Secrets Helper Library
# ==============================================================================

{
  lib,
  secretsDir ? "/run/agenix",
}:

let
  secretsRoot = ../secrets;
  secretFile = name: "${secretsRoot}/${name}.age";
  secretAttrName = name: lib.replaceStrings [ "." "/" ] [ "-" "-" ] name;
  secretPath = name: "${secretsDir}/${secretAttrName name}";
  mkSecret =
    {
      name,
      file ? secretFile name,
      owner ? "root",
      group ? owner,
      mode ? "0400",
      path ? null,
    }:
    {
      inherit
        file
        owner
        group
        mode
        ;
    }
    // lib.optionalAttrs (path != null) { inherit path; };
in
{
  inherit
    secretFile
    secretPath
    mkSecret
    ;

  # ----------------------------------------------------------------------------
  # User Secret Requirements
  # ----------------------------------------------------------------------------

  mkRequiredUserSecrets =
    {
      homeConfig,
      userConfig,
      group ? null,
    }:
    lib.mapAttrs' (
      attrName: spec:
      let
        name = spec.name or attrName;
        owner = userConfig.name;
        secretGroup = if group != null then group else userConfig.group or owner;
      in
      lib.nameValuePair (secretAttrName attrName) (mkSecret {
        inherit name owner;
        group = secretGroup;
        mode = "0400";
        path = if (spec.path or null) != null then spec.path else secretPath attrName;
      })
    ) (homeConfig.hakula.secrets.required or { });
}
