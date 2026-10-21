# ==================================================================================================
# LLM Assistants
# ==================================================================================================

{
  lib,
}:

let
  mcpOptions = import ./mcp-options.nix { inherit lib; };

  covers = command: other: command == other || lib.hasPrefix "${command} " other;

  duplicates = list: lib.unique (lib.filter (item: lib.count (other: other == item) list > 1) list);

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

  withEntries =
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

  checkPermissions =
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

      mcpServers = builtins.attrNames policy.allows.mcp ++ builtins.attrNames policy.gates.mcp;
      unknownServers = lib.unique (lib.subtractLists mcpOptions.allServerNames mcpServers);

      toMcpId = entry: "${entry.server}.${entry.tool}";
      mcpAllows = map toMcpId policy.mcpAllows;
      mcpGates = map toMcpId policy.mcpGates;

      wildcards = lib.filter (lib.hasInfix "*") (allCommands ++ mcpAllows ++ mcpGates);

      errors =
        overlaps
        ++ map (item: "`${item}` is listed more than once") (
          duplicates allCommands ++ duplicates mcpAllows ++ duplicates mcpGates
        )
        ++ map (item: "`${item}` contains `*`") wildcards
        ++ map (server: "unknown MCP server `${server}`") unknownServers
        ++ map (tool: "MCP tool `${tool}` is both allowed and gated") (
          lib.intersectLists mcpAllows mcpGates
        );
    in
    lib.throwIf (errors != [ ]) "permissions.nix: ${lib.concatStringsSep "; " errors}" policy;

  permissions = checkPermissions (withEntries (import ./permissions.nix));
in
{
  inherit mcpOptions permissions;

  mkProfileDefinitions = import ./profiles.nix;

  mkOptions =
    {
      mkProxyOptions,
      enableDescription,
      defaultUser,
    }:
    {
      enable = lib.mkEnableOption enableDescription;

      user = lib.mkOption {
        type = lib.types.str;
        default = defaultUser;
        description = "Home Manager user to receive assistant defaults";
      };

      mcp = {
        disabledServers = mcpOptions.mkDisabledServersOption {
          description = "MCP servers to disable across all LLM assistants";
        };
      };

      proxy = mkProxyOptions "LLM assistants";
    };

  mkHomeManagerConfig = cfg: {
    home-manager.users.${cfg.user}.hakula.llm-assistants = {
      enable = lib.mkDefault true;
      mcp.disabledServers = lib.mkDefault cfg.mcp.disabledServers;
      proxy = lib.mkIf cfg.proxy.enable {
        enable = lib.mkDefault true;
        url = lib.mkDefault cfg.proxy.url;
        secretUrlFile = lib.mkDefault cfg.proxy.secretUrlFile;
        noProxy = lib.mkDefault cfg.proxy.noProxy;
      };
    };
  };
}
