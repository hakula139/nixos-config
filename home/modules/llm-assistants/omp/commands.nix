# ==================================================================================================
# OMP Custom Commands
# ==================================================================================================

{
  pkgs,
  lib,
  sharedCommands,
}:

let
  # Bun resolves symlinks in import.meta.dir, so the adapter needs real copies of its templates.
  commandDir = pkgs.runCommandLocal "omp-shared-commands" { } ''
    install -Dm444 ${./scripts/shared-commands.ts} "$out/index.ts"
    ${lib.concatMapAttrsStringSep "\n" (
      name: path: ''install -m444 ${path} "$out/${name}.md"''
    ) sharedCommands}
  '';
in
{
  homeFiles.".omp/agent/commands/shared" = {
    source = commandDir;
    recursive = true;
  };
}
