# ==================================================================================================
# LLM Assistant Permissions
# ==================================================================================================

{
  lib,
  mcpOptions,
}:

let
  validate = import ./validate.nix { inherit lib mcpOptions; };

  toMcpEntries =
    servers:
    lib.concatLists (
      lib.mapAttrsToList (
        server:
        map (
          entry:
          entry
          // {
            inherit server;
            displayName = mcpOptions.serverDisplayNames.${server};
          }
        )
      ) servers
    );

  toArgumentPatterns =
    command: argument:
    if lib.hasPrefix "-" argument then
      [ "${command} *${argument}*" ]
    else
      [
        "${command} ${argument}"
        "${command} ${argument} *"
        "${command} * ${argument}"
        "${command} * ${argument} *"
      ];

  withFlatLists =
    policy:
    policy
    // {
      allowCommands = policy.allows.commands.readOnly ++ policy.allows.commands.mutating;
      gateCommands = map (gate: gate.command) policy.gates.commands;
      argumentCommands = lib.unique (lib.concatMap (gate: gate.commands) policy.gates.arguments);
      argumentPatterns = lib.concatMap (
        gate:
        lib.concatMap (command: lib.concatMap (toArgumentPatterns command) gate.arguments) gate.commands
      ) policy.gates.arguments;
      mcpAllows = toMcpEntries (
        lib.mapAttrs (
          _:
          map (tool: {
            inherit tool;
          })
        ) policy.allows.mcp
      );
      mcpGates = toMcpEntries policy.gates.mcp;
    };
in
validate (withFlatLists {
  gates = import ./gates.nix;
  allows = import ./allows.nix;
})
