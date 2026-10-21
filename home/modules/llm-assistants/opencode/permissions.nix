# ==================================================================================================
# OpenCode Permissions
# ==================================================================================================

{
  lib,
  policy,
}:

let
  inherit (policy) allows;

  toolNames = {
    webFetch = "webfetch";
    webSearch = "websearch";
  };

  # Each command gets a bare and a prefixed key so `rm` never matches `rmdir`.
  toBashRules =
    decision: commands:
    lib.listToAttrs (
      lib.concatMap (command: [
        (lib.nameValuePair command decision)
        (lib.nameValuePair "${command} *" decision)
      ]) commands
    );

  # OpenCode names an MCP tool's permission `<Server>_<tool>`.
  toMcpRules =
    decision: entries:
    lib.listToAttrs (
      map (entry: lib.nameValuePair "${entry.displayName}_${entry.tool}" decision) entries
    );
in
{
  # OpenCode resolves permission.bash last-match-wins, and Nix serializes keys alphabetically
  # (attrsets are unordered: nix-community/home-manager#2519). Each ask overrides `*` because `*`
  # sorts before every command name, and no allow can match a gated command, because evaluation
  # rejects an allow that overlaps a gate. Nothing contains a command that OpenCode runs, so only
  # read-only commands render as allows.
  bash = {
    "*" = "allow";
  }
  // toBashRules "allow" allows.commands.readOnly
  // toBashRules "ask" policy.gateCommands
  // lib.genAttrs policy.argumentPatterns (_: "ask");

  external_directory = lib.genAttrs (map (path: "${path}/*") allows.paths) (_: "allow");
}
// lib.genAttrs (map (tool: toolNames.${tool}) allows.tools) (_: "allow")
// toMcpRules "allow" policy.mcpAllows
// toMcpRules "ask" policy.mcpGates
