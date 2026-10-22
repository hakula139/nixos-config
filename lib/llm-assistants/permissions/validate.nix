# ==================================================================================================
# LLM Assistant Permission Validation
# ==================================================================================================

{
  lib,
  mcpOptions,
  policy,
}:

let
  inherit (policy) allowCommands gateCommands;
  allCommands = allowCommands ++ gateCommands;

  covers = command: other: command == other || lib.hasPrefix "${command} " other;

  duplicates = list: lib.unique (lib.filter (item: lib.count (other: other == item) list > 1) list);

  overlaps = lib.concatMap (
    allow:
    map (gate: "allow `${allow}` overlaps gate `${gate}`") (
      lib.filter (gate: covers allow gate || covers gate allow) gateCommands
    )
  ) allowCommands;

  # Codex runs read-only allows outside its sandbox.
  readOnlyCovers = lib.concatMap (
    readOnly:
    map (mutating: "read-only `${readOnly}` covers mutating `${mutating}`") (
      lib.filter (covers readOnly) policy.allows.commands.mutating
    )
  ) policy.allows.commands.readOnly;

  mcpServers = builtins.attrNames policy.allows.mcp ++ builtins.attrNames policy.gates.mcp;
  unknownServers = lib.unique (lib.subtractLists mcpOptions.allServerNames mcpServers);

  toMcpId = entry: "${entry.server}.${entry.tool}";
  mcpAllowIds = map toMcpId policy.mcpAllows;
  mcpGateIds = map toMcpId policy.mcpGates;

  wildcards = lib.filter (lib.hasInfix "*") (allCommands ++ mcpAllowIds ++ mcpGateIds);

  errors =
    overlaps
    ++ readOnlyCovers
    ++ map (item: "`${item}` is listed more than once") (
      duplicates allCommands ++ duplicates mcpAllowIds ++ duplicates mcpGateIds
    )
    ++ map (item: "`${item}` contains `*`") wildcards
    ++ map (server: "unknown MCP server `${server}`") unknownServers
    ++ map (tool: "MCP tool `${tool}` is both allowed and gated") (
      lib.intersectLists mcpAllowIds mcpGateIds
    );

  message = "lib/llm-assistants/permissions: ${lib.concatStringsSep "; " errors}";
in
lib.throwIf (errors != [ ]) message policy
