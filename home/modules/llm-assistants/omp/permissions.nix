# ==================================================================================================
# OMP Permissions
# ==================================================================================================

{
  lib,
  policy,
}:

let
  sanitize =
    value:
    lib.concatStringsSep "_" (
      lib.filter (part: lib.isString part && part != "") (builtins.split "[^a-z0-9]+" (lib.toLower value))
    );

  # Mirrors OMP's mintMCPToolName, which hashes names over 64 characters in a way Nix can't
  # reproduce, so a longer name fails evaluation.
  toToolName =
    entry:
    let
      server = sanitize entry.displayName;
      name = "mcp__${server}_${lib.removePrefix "${server}_" (sanitize entry.tool)}";
    in
    lib.throwIf (lib.stringLength name > 64) "OMP would hash the MCP tool name `${name}`" name;

  toBashRules =
    approval: commands:
    lib.concatMap (
      command:
      map (match: { inherit match approval; }) [
        command
        "${command} *"
      ]
    ) commands;
in
{
  tools = {
    # In yolo mode, critical-command overrides can bypass Bash prompt rules.
    approvalMode = "write";
    approval = {
      bash = "allow";
      # Eval can execute shells without passing through Bash's command rules.
      eval = "prompt";
    }
    // lib.listToAttrs (map (gate: lib.nameValuePair (toToolName gate) "prompt") policy.mcpGates);
  };

  # OMP applies the first matching pattern, so prompts precede allows.
  bash.patterns =
    toBashRules "prompt" policy.gateCommands ++ toBashRules "allow" policy.allows.commands.readOnly;
}
