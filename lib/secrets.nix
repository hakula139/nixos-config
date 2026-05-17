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
  secretPath = name: "${secretsDir}/${name}";
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
      pathCollisions = lib.filter (g: builtins.length g > 1) (
        builtins.attrValues (builtins.groupBy (n: required.${n}.path) (builtins.attrNames required))
      );
      formatGroups = lib.concatMapStringsSep "; " (g: lib.concatStringsSep " == " g);
    in
    assert lib.assertMsg (pathCollisions == [ ]) ''
      hakula.secrets.required entries share a destination path: ${formatGroups pathCollisions}
      (each `path` override must be unique; the second decrypt would overwrite the first)
    '';
    lib.mapAttrs (
      _: spec:
      mkSecret {
        inherit (spec) name path;
        owner = userConfig.name;
        group = if group != null then group else userConfig.group or userConfig.name;
      }
    ) required;
}
