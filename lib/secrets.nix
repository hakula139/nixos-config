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
    let
      inherit (homeConfig.hakula.secrets) required;
      attrNames = builtins.attrNames required;
      collisions = lib.filter (group: builtins.length group > 1) (
        builtins.attrValues (lib.groupBy secretAttrName attrNames)
      );
    in
    assert lib.assertMsg (collisions == [ ]) ''
      hakula.secrets.required keys collide after normalization: ${
        lib.concatMapStringsSep "; " (g: lib.concatStringsSep " == " g) collisions
      }
      (`.` and `/` both normalize to `-` for the age.secrets attribute name)
    '';
    lib.mapAttrs' (
      attrName: spec:
      let
        owner = userConfig.name;
        secretGroup = if group != null then group else userConfig.group or owner;
      in
      lib.nameValuePair (secretAttrName attrName) (mkSecret {
        inherit owner;
        inherit (spec) name path;
        group = secretGroup;
        mode = "0400";
      })
    ) required;
}
