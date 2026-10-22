# ==================================================================================================
# LLM Assistant Permission Validation
# ==================================================================================================

{
  lib,
  mcpOptions,
}:

let
  covers = command: other: command == other || lib.hasPrefix "${command} " other;

  duplicates = list: lib.unique (lib.filter (item: lib.count (other: other == item) list > 1) list);
in
policy:
let
  inherit (policy) allowCommands gateCommands;
  allCommands = allowCommands ++ gateCommands;

  overlaps = lib.concatMap (
    allow:
    map (gate: "allow `${allow}` overlaps gate `${gate}`") (
      lib.filter (gate: covers allow gate || covers gate allow) gateCommands
    )
  ) allowCommands;

  # Codex runs read-only allows outside its sandbox and can't match a flag at an arbitrary
  # position, so a read-only prefix must not reach a mutating command or a gated argument.
  readOnlyCovers = lib.concatMap (
    readOnly:
    map (mutating: "read-only `${readOnly}` covers mutating `${mutating}`") (
      lib.filter (covers readOnly) policy.allows.commands.mutating
    )
  ) policy.allows.commands.readOnly;

  readOnlyExecutors = lib.concatMap (
    readOnly:
    map (command: "read-only `${readOnly}` overlaps gated arguments of `${command}`") (
      lib.filter (command: covers readOnly command || covers command readOnly) policy.argumentCommands
    )
  ) policy.allows.commands.readOnly;

  mcpServers = builtins.attrNames policy.allows.mcp ++ builtins.attrNames policy.gates.mcp;
  unknownServers = lib.unique (lib.subtractLists mcpOptions.allServerNames mcpServers);

  toMcpId = entry: "${entry.server}.${entry.tool}";
  mcpAllowIds = map toMcpId policy.mcpAllows;
  mcpGateIds = map toMcpId policy.mcpGates;

  arguments = lib.concatMap (gate: gate.arguments) policy.gates.arguments;

  wildcards = lib.filter (lib.hasInfix "*") (
    allCommands ++ policy.argumentCommands ++ arguments ++ mcpAllowIds ++ mcpGateIds
  );

  errors =
    overlaps
    ++ readOnlyCovers
    ++ readOnlyExecutors
    ++ map (item: "`${item}` is listed more than once") (
      duplicates allCommands
      ++ duplicates policy.argumentPatterns
      ++ duplicates mcpAllowIds
      ++ duplicates mcpGateIds
    )
    ++ map (item: "`${item}` contains `*`") wildcards
    ++ map (server: "unknown MCP server `${server}`") unknownServers
    ++ map (tool: "MCP tool `${tool}` is both allowed and gated") (
      lib.intersectLists mcpAllowIds mcpGateIds
    );
in
lib.throwIf (
  errors != [ ]
) "lib/llm-assistants/permissions: ${lib.concatStringsSep "; " errors}" policy
