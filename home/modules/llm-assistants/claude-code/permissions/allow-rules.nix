# ==================================================================================================
# Claude Code Allow Rules
# ==================================================================================================

{
  lib,
  shared,
  skillScriptPaths,
}:

let
  inherit (shared.permissions) allowCommands mcpAllows;
  inherit (shared.permissions.allows) paths tools;

  toolNames = {
    webFetch = "WebFetch";
    webSearch = "WebSearch";
  };

  # Claude Code's `Bash(ls *)` matches `ls` with or without arguments.
  commandRules = map (command: "Bash(${command} *)") allowCommands;

  skillRules = map (path: "Bash(${path} *)") skillScriptPaths;

  mcpRules = map (entry: "mcp__${entry.displayName}__${entry.tool}") mcpAllows;

  toolRules = map (tool: toolNames.${tool}) tools;

  # A leading `//` makes a Claude Code path rule absolute.
  pathRules = lib.concatMap (path: [
    "Read(/${path}/**)"
    "Edit(/${path}/**)"
  ]) paths;

  # The built-in IDE server is outside the shared MCP registry.
  builtinRules = [
    "mcp__ide"
  ];
in
commandRules ++ skillRules ++ mcpRules ++ toolRules ++ pathRules ++ builtinRules
