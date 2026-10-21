# ==================================================================================================
# LLM Assistants
# ==================================================================================================

{
  lib,
}:

let
  mcpOptions = import ./mcp-options.nix { inherit lib; };

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

  covers = command: other: command == other || lib.hasPrefix "${command} " other;

  duplicates = list: lib.unique (lib.filter (item: lib.count (other: other == item) list > 1) list);

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
    lib.throwIf (errors != [ ]) "permissions.nix: ${lib.concatStringsSep "; " errors}" policy;

  permissions = checkPermissions (withFlatLists (import ./permissions.nix));
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
