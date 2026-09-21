# ==============================================================================
# Codex Skills
# ==============================================================================

{
  config,
  pkgs,
  lib,
  configDir,
  sharedSkills,
}:

let
  managedSkills = lib.filterAttrs (
    _: file: file.enable && lib.hasPrefix ".agents/skills/" file.target
  ) config.home.file;

  skillBundle = pkgs.linkFarm "codex-managed-skills" (
    lib.mapAttrsToList (_: file: {
      name = lib.removePrefix ".agents/skills/" file.target;
      path = file.source;
    }) managedSkills
    ++ lib.mapAttrsToList (name: path: { inherit name path; }) sharedSkills
  );
in
{
  # Codex 0.153.4 skips Home Manager's symlinked skills during discovery.
  activation = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run install -d -m 0700 ${lib.escapeShellArg "${configDir}/skills/nixos-config"}
    run ${lib.getExe pkgs.rsync} -rpL --delete --chmod=u=rwX,go= \
      ${skillBundle}/ ${lib.escapeShellArg "${configDir}/skills/nixos-config/"}
  '';

  settings = {
    bundled.enabled = true;
  };
}
