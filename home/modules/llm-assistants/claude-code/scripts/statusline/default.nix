# ==================================================================================================
# Claude Code Status Line Package
# ==================================================================================================
# Packages the renderer with ccusage and its generated model catalog.
# ==================================================================================================

{
  pkgs,
  lib,
  repoLib,
  modelCatalog,
}:

repoLib.mkNuCommand {
  inherit pkgs;
  name = "statusline-command";
  script = ./statusline-command.nu;
  runtimeInputs = [
    pkgs.ccusage
    pkgs.coreutils
    pkgs.flock
    pkgs.git
  ];

  config.models = lib.listToAttrs (
    lib.concatLists (
      lib.mapAttrsToList (
        id: model:
        map (name: lib.nameValuePair name model.name) ([ id ] ++ builtins.attrValues model.channelId)
      ) modelCatalog.models
    )
  );
}
