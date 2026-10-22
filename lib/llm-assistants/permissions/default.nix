# ==================================================================================================
# LLM Assistant Permissions
# ==================================================================================================

{
  lib,
  mcpOptions,
}:

let
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

  withFlatLists =
    policy:
    policy
    // {
      allowCommands = policy.allows.commands.readOnly ++ policy.allows.commands.mutating;
      gateCommands = map (gate: gate.command) policy.gates.commands;
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

  policy = withFlatLists {
    gates = import ./gates.nix;
    allows = import ./allows.nix;
  };
in
import ./validate.nix { inherit lib mcpOptions policy; }
