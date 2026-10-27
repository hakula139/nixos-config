# ==================================================================================================
# Prose Polish Skill
# ==================================================================================================
# The installed skill directory: its instructions, its agent metadata, and the wrapper that carries
# the model call and prompts. Tests and the stub stay out of the installed directory.
# ==================================================================================================

{
  pkgs,
  lib,
  mkNuCommand,
  modelCall,
  modelCatalog,
  phrasing,
}:

let
  # Every catalog model sits on a single gateway channel.
  models = lib.mapAttrs (
    _: model: lib.head (builtins.attrValues model.channelId)
  ) modelCatalog.models;

  command = mkNuCommand {
    name = "prose-polish";
    script = ./scripts/prose-polish.nu;
    config = {
      inherit
        phrasing
        models
        modelCall
        ;
      maxRepairs = 3;
      model = models.gemini-4-argon;
      prompt = builtins.readFile ./scripts/prompt.md;
      repairPrompt = builtins.readFile ./scripts/repair-prompt.md;
    };
  };
in
pkgs.linkFarm "prose-polish-skill" [
  {
    name = "SKILL.md";
    path = ./SKILL.md;
  }
  {
    name = "agents/openai.yaml";
    path = ./agents/openai.yaml;
  }
  {
    name = "scripts/prose-polish";
    path = lib.getExe command;
  }
]
