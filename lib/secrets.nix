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

  mkRequiredUserSecrets =
    {
      homeConfig,
      userConfig,
      group ? null,
    }:
    let
      inherit (homeConfig.hakula.secrets) required;
      attrNames = builtins.attrNames required;
      nameCollisions = lib.filter (group: builtins.length group > 1) (
        builtins.attrValues (lib.groupBy secretAttrName attrNames)
      );
      pathCollisions = lib.filter (group: builtins.length group > 1) (
        builtins.attrValues (lib.groupBy (n: required.${n}.path) attrNames)
      );
      formatGroups = lib.concatMapStringsSep "; " (g: lib.concatStringsSep " == " g);
    in
    assert lib.assertMsg (nameCollisions == [ ]) ''
      hakula.secrets.required keys collide after normalization: ${formatGroups nameCollisions}
      (`.` and `/` both normalize to `-` for the age.secrets attribute name)
    '';
    assert lib.assertMsg (pathCollisions == [ ]) ''
      hakula.secrets.required entries share a destination path: ${formatGroups pathCollisions}
      (each `path` override must be unique; the second decrypt would overwrite the first)
    '';
    lib.mapAttrs' (
      attrName: spec:
      lib.nameValuePair (secretAttrName attrName) (mkSecret {
        inherit (spec) name path;
        owner = userConfig.name;
        group = if group != null then group else userConfig.group or userConfig.name;
      })
    ) required;
}
