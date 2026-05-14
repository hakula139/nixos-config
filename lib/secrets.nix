# ==============================================================================
# Secrets Helper Library
# ==============================================================================

{
  lib,
  secretsDir ? ".secrets",
}:

let
  secretsRoot = ../secrets;
  secretFile = name: "${secretsRoot}/${name}.age";
  secretsPath = homeDir: "${homeDir}/${secretsDir}";
  secretAttrName = name: lib.replaceStrings [ "." "/" ] [ "-" "-" ] name;
in
rec {
  inherit secretAttrName secretFile secretsPath;

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

  # User-owned secret decrypted into the shared per-user secret tree.
  mkUserSecret =
    {
      name,
      user,
      file ? secretFile name,
      group ? null,
      homeDir ? null,
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
      userHome =
        if homeDir != null then
          homeDir
        else if isUserAttrs && user ? home then
          user.home
        else
          throw "mkUserSecret requires homeDir when user has no home";
    in
    mkSecret {
      inherit
        name
        file
        mode
        ;
      inherit owner;
      group = userGroup;
      path = if path != null then path else "${secretsPath userHome}/${name}";
    };

  mkUserSecrets =
    {
      specs,
      user,
      group ? null,
      homeDir ? null,
      mode ? "0400",
      overrides ? { },
    }:
    builtins.listToAttrs (
      lib.mapAttrsToList (
        attrName: spec:
        let
          secret = spec // (overrides.${attrName} or overrides.${spec.name or attrName} or { });

          secretGroup = if (secret.group or null) != null then secret.group else group;
          secretHomeDir = if (secret.homeDir or null) != null then secret.homeDir else homeDir;
        in
        {
          name = attrName;
          value = mkUserSecret (
            {
              name = secret.name or attrName;
              inherit user;
              mode = secret.mode or mode;
            }
            // lib.optionalAttrs ((secret.file or null) != null) { inherit (secret) file; }
            // lib.optionalAttrs ((secret.path or null) != null) { inherit (secret) path; }
            // lib.optionalAttrs (secretGroup != null) { group = secretGroup; }
            // lib.optionalAttrs (secretHomeDir != null) { homeDir = secretHomeDir; }
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
      homeDir ? null,
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
      // lib.optionalAttrs (homeDir != null) { inherit homeDir; }
    );

  # ----------------------------------------------------------------------------
  # Directory Management
  # ----------------------------------------------------------------------------

  # Generate systemd.tmpfiles.rules entry for the user secrets directory.
  mkSecretsDir =
    user: group:
    let
      owner = user.name or (throw "mkSecretsDir requires user.name");
    in
    [
      "d ${secretsPath user.home} 0700 ${owner} ${group} - -"
    ];
}
