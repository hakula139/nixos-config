# ==================================================================================================
# Claude Code Allow Rules
# ==================================================================================================

{
  lib,
  policy,
  skillScripts,
  skillsDir,
}:

let
  inherit (policy) allows;

  toolNames = {
    webFetch = "WebFetch";
    webSearch = "WebSearch";
  };

  # Claude Code's `Bash(ls *)` matches `ls` with or without arguments, but never `lsof`.
  commandRules = map (command: "Bash(${command} *)") policy.allowCommands;

  skillRules = map (script: "Bash(${skillsDir}/${script.skill}/${script.file} *)") skillScripts;

  mcpRules = map (entry: "mcp__${entry.displayName}__${entry.tool}") policy.mcpAllows;

  toolRules = map (tool: toolNames.${tool}) allows.tools;

  # A leading `//` makes a Claude Code path rule absolute.
  pathRules = lib.concatMap (path: [
    "Read(/${path}/**)"
    "Edit(/${path}/**)"
  ]) allows.paths;

  # The built-in IDE server is outside the shared MCP registry.
  builtinRules = [
    "mcp__ide"
  ];
in
commandRules ++ skillRules ++ mcpRules ++ toolRules ++ pathRules ++ builtinRules
