# ==================================================================================================
# LLM Assistant Permissions
# ==================================================================================================

{
  lib,
  mcpOptions,
}:

let
  gates = import ./gates.nix;
  allows = import ./allows.nix;

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

  policy = {
    inherit gates allows;
    allowCommands = allows.commands.readOnly ++ allows.commands.mutating;
    gateCommands = map (gate: gate.command) gates.commands;
    mcpAllows = toMcpEntries (
      lib.mapAttrs (
        _:
        map (tool: {
          inherit tool;
        })
      ) allows.mcp
    );
    mcpGates = toMcpEntries gates.mcp;
  };
in
import ./validate.nix { inherit lib mcpOptions policy; }
