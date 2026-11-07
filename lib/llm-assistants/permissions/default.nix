# ==================================================================================================
# LLM Assistant Permissions
# ==================================================================================================

{
  lib,
  corpHosts,
  mcpOptions,
}:

let
  sourceControl = import ./source-control.nix {
    inherit corpHosts;
  };
  allows = import ./allows.nix {
    inherit (sourceControl) ownRepositories;
  };
  gates = import ./gates.nix;

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
    inherit sourceControl allows gates;
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
