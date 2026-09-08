# ==============================================================================
# Shared Skills
# ==============================================================================

{ lib }:

let
  sources = {
    git-workflow = ./git-workflow;
  };
in
{
  inherit sources;

  # OpenCode also discovers Claude's directory. Both modules declare the same
  # targets so Home Manager installs each shared skill once.
  homeFile = lib.mapAttrs' (
    name: source:
    lib.nameValuePair ".claude/skills/${name}" {
      inherit source;
      recursive = true;
    }
  ) sources;
}
