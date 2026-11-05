# ==================================================================================================
# Codex Skills
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  configDir,
  shared,
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
    ++ lib.mapAttrsToList (name: path: { inherit name path; }) shared.skills
  );

  bundleDir = "${configDir}/skills/nixos-config";
in
{
  # Codex 0.153.4 skips Home Manager's symlinked skills during discovery.
  activation = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run install -dm0700 ${lib.escapeShellArg bundleDir}

    run ${lib.getExe pkgs.rsync} ${skillBundle}/ ${lib.escapeShellArg "${bundleDir}/"} \
      -rpL \
      --delete \
      --chmod=u=rwX,go=
  '';

  settings = {
    bundled.enabled = true;
  };
}
