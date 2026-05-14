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

  normalizeSecretSpec =
    attrName: spec:
    if builtins.isString spec then
      {
        name = attrName;
        path = spec;
      }
    else
      spec // lib.optionalAttrs (!(spec ? name)) { name = attrName; };
in
rec {
  inherit secretAttrName secretFile secretPath;

  # ----------------------------------------------------------------------------
  # Secret Declarations
  # ----------------------------------------------------------------------------

  # Standard secret configuration for an age.secrets entry.
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

  # User-owned secret materialized by the platform age.secrets backend.
  mkUserSecret =
    {
      name,
      user,
      file ? secretFile name,
      group ? null,
      mode ? "0400",
      path ? null,
    }:
    let
      isUserAttrs = builtins.isAttrs user;
      owner = if isUserAttrs then user.name else user;
      userGroup =
        if group != null then
          group
        else if isUserAttrs && user ? group then
          user.group
        else
          owner;
    in
    mkSecret {
      inherit
        name
        file
        mode
        ;
      inherit owner;
      group = userGroup;
      path = if path != null then path else secretPath name;
    };

  mkUserSecrets =
    {
      specs,
      user,
      group ? null,
      mode ? "0400",
      overrides ? { },
    }:
    builtins.listToAttrs (
      lib.mapAttrsToList (
        attrName: spec:
        let
          baseSecret = normalizeSecretSpec attrName spec;
          secret = baseSecret // (overrides.${attrName} or overrides.${baseSecret.name} or { });

          secretGroup = if (secret.group or null) != null then secret.group else group;
        in
        {
          name = secretAttrName attrName;
          value = mkUserSecret (
            {
              inherit (secret) name;
              inherit user;
              mode = secret.mode or mode;
              path = secret.path or (secretPath attrName);
            }
            // lib.optionalAttrs ((secret.file or null) != null) { inherit (secret) file; }
            // lib.optionalAttrs (secretGroup != null) { group = secretGroup; }
          );
        }
      ) specs
    );

  mkUserSecretSpecs =
    specs:
    builtins.listToAttrs (
      map (
        spec:
        let
          normalized = if builtins.isString spec then { name = spec; } else spec;
          name = normalized.name or (throw "mkUserSecretSpecs requires each spec to define name");
          attrName = normalized.attrName or secretAttrName name;
        in
        {
          name = attrName;
          value = builtins.removeAttrs normalized [ "attrName" ];
        }
      ) specs
    );

  mkRequiredUserSecrets =
    {
      homeConfig,
      userConfig,
      group ? null,
      mode ? "0400",
      overrides ? { },
    }:
    mkUserSecrets (
      {
        specs = homeConfig.hakula.secrets.required or { };
        user = userConfig;
        inherit
          mode
          overrides
          ;
      }
      // lib.optionalAttrs (group != null) { inherit group; }
    );
}
