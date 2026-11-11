# ==================================================================================================
# Claude Code Allow Rules
# ==================================================================================================

{
  lib,
  shared,
}:

let
  policy = shared.permissions;
  inherit (policy) allows;

  toolNames = {
    webFetch = "WebFetch";
    webSearch = "WebSearch";
  };

  # Claude Code's `Bash(ls *)` matches `ls` with or without arguments, but never `lsof`.
  toAllowRule = command: "Bash(${command} *)";

  commandRules = map toAllowRule policy.allowCommands;

  skillRules = map toAllowRule (shared.mkSkillScriptPaths "${shared.claudeConfigDir}/skills");

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
