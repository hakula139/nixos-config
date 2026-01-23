{
  lib,
  secretsDir ? ".secrets",
}:

# ==============================================================================
# Secrets Helper Library
# ==============================================================================

let
  secretsRoot = ../secrets;
  secretFile = scope: name: "${secretsRoot}/${scope}/${name}.age";
  secretsPath = homeDir: "${homeDir}/${secretsDir}";
in
{
  inherit secretFile secretsPath;

  # ----------------------------------------------------------------------------
  # Secret Declarations
  # ----------------------------------------------------------------------------

  # Standard secret configuration for NixOS modules
  # Returns an age.secrets.<name> configuration for system-level agenix
  mkSecret =
    {
      scope ? "shared",
      name,
      owner,
      group,
      mode ? "0400",
      path ? null,
    }:
    {
      file = secretFile scope name;
      inherit owner group mode;
    }
    // lib.optionalAttrs (path != null) { inherit path; };

  # Standard Home Manager secret configuration
  # Returns an age.secrets.<name> configuration for home-manager agenix
  mkHomeSecret =
    {
      scope ? "shared",
      name,
      homeDir,
      mode ? "0400",
      path ? null,
    }:
    let
      defaultPath = "${secretsPath homeDir}/${name}";
    in
    {
      file = secretFile scope name;
      path = if path != null then path else defaultPath;
      inherit mode;
    };

  # ----------------------------------------------------------------------------
  # Directory Management
  # ----------------------------------------------------------------------------

  # Generate systemd.tmpfiles.rules entry for secrets directory (NixOS)
  mkSecretsDir = user: group: [
    "d ${secretsPath user.home} 0700 ${user.name} ${group} - -"
  ];

  # Generate home.activation script for secrets directory (Home Manager)
  mkHomeSecretsDir = homeDir: ''
    install -d -m 0700 "${secretsPath homeDir}"
  '';
}
