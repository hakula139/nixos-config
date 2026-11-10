# ==================================================================================================
# Prose Polish Skill
# ==================================================================================================
# The installed skill directory: its instructions, agent metadata, and evaluation reference, plus
# the wrapper that carries the model call and prompts. Tests and the stub stay out of the
# installed directory.
# ==================================================================================================

{
  pkgs,
  lib,
  modelCall,
  modelCatalog,
  promptFragments,
  repoLib,
}:

let
  skillScript = "scripts/prose-polish";

  json = pkgs.formats.json { };

  # Every catalog model sits on a single gateway channel.
  models = lib.mapAttrs (
    _: model: lib.head (builtins.attrValues model.channelId)
  ) modelCatalog.models;

  config = json.generate "prose-polish.json" {
    inherit
      models
      modelCall
      ;
    inherit (promptFragments) phrasing;
    maxRepairs = 3;
    model = models.gemini-4-argon;
    prompt = builtins.readFile ./scripts/prompt.md;
    repairPrompt = builtins.readFile ./scripts/repair-prompt.md;
  };

  command = repoLib.mkNuCommand {
    inherit pkgs;
    name = "prose-polish";
    script = ./scripts/prose-polish.nu;
    runtimeInputs = [ pkgs.coreutils ];

    makeWrapperArgs = [
      "--set"
      "PROSE_POLISH_CONFIG"
      config
    ];
  };

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./SKILL.md
      ./agents
      ./references
    ];
  };
in
pkgs.runCommand "prose-polish-skill" { passthru.scripts = [ skillScript ]; } ''
  cp -r --no-preserve=mode ${src} "$out"
  install -Dm0755 ${lib.getExe command} "$out/${skillScript}"
''
