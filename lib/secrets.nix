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
in
rec {
  inherit secretFile secretsPath;

  # ----------------------------------------------------------------------------
  # Secret Declarations
  # ----------------------------------------------------------------------------

  # Standard secret configuration for NixOS modules
  # Returns an age.secrets.<name> configuration for system-level agenix
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

  # User-owned secret decrypted into the shared per-user secret tree
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
          builtins.throw "mkUserSecret requires homeDir when user has no home";
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
      names,
      user,
      group ? null,
      homeDir ? null,
      mode ? "0400",
      rename ? name: lib.replaceStrings [ "." "/" ] [ "-" "-" ] name,
      overrides ? { },
    }:
    builtins.listToAttrs (
      map (
        secretName:
        let
          attrName = rename secretName;
          override = overrides.${attrName} or overrides.${secretName} or { };
        in
        {
          name = attrName;
          value = mkUserSecret (
            {
              name = secretName;
              inherit user mode;
            }
            // lib.optionalAttrs (group != null) { inherit group; }
            // lib.optionalAttrs (homeDir != null) { inherit homeDir; }
            // override
          );
        }
      ) names
    );

  mkUserSecretsFromSpecs =
    {
      specs,
      user,
      group ? null,
      homeDir ? null,
      mode ? "0400",
      overrides ? { },
    }:
    lib.mapAttrs (
      attrName: spec:
      let
        secret = spec // (overrides.${attrName} or { });
      in
      mkUserSecret (
        {
          name = secret.name or attrName;
          inherit user;
          mode = secret.mode or mode;
        }
        // lib.optionalAttrs (secret ? file) { inherit (secret) file; }
        // lib.optionalAttrs (secret ? path) { inherit (secret) path; }
        // lib.optionalAttrs (group != null) { inherit group; }
        // lib.optionalAttrs (homeDir != null) { inherit homeDir; }
      )
    ) specs;

  # ----------------------------------------------------------------------------
  # Directory Management
  # ----------------------------------------------------------------------------

  # Generate systemd.tmpfiles.rules entry for secrets directory (NixOS)
  mkSecretsDir =
    user: group:
    let
      owner = user.name or (builtins.throw "mkSecretsDir requires user.name");
    in
    [
      "d ${secretsPath user.home} 0700 ${owner} ${group} - -"
    ];
}
