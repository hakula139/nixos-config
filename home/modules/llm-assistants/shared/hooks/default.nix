# ==================================================================================================
# Shared Hooks
# ==================================================================================================
# Claude Code and Codex name their events alike, so a hook states its own event and only its tool
# classes need translating. Each adapter owns that map and hands it to `mkHooks`.
# ==================================================================================================

{
  pkgs,
  lib,
  dataHome,
  modelCatalog,
  promptFragments,
  fileFormatter,
  timeouts,
  repoLib,
  mkModelCall,
}:

{
  assistant,
  toolClasses,
  enableCorpGateway,
}:

let
  # ------------------------------------------------------------------------------------------------
  # Hook command generation
  # ------------------------------------------------------------------------------------------------
  mkNuHook =
    {
      slug,
      script,
      runtimeInputs ? [ ],
      config ? null,
    }:
    lib.getExe (
      repoLib.mkNuCommand {
        inherit pkgs script config;
        name = "${assistant}-${slug}";
        runtimeInputs = [ pkgs.coreutils ] ++ runtimeInputs;
      }
    );

  patchInput = lib.getExe (
    pkgs.writers.writeNuBin "patch-input" (builtins.readFile ./lib/patch-input/patch-input.nu)
  );

  modelCall = mkModelCall { inherit assistant; };

  # ------------------------------------------------------------------------------------------------
  # Hook entries
  # ------------------------------------------------------------------------------------------------
  mkMatcher =
    tools: lib.concatStringsSep "|" (lib.unique (lib.concatMap (tool: toolClasses.${tool}) tools));

  handlerFields = [
    "type"
    "command"
    "prompt"
    "timeout"
    "statusMessage"
    "async"
  ];

  mkEntry =
    hook:
    lib.optionalAttrs (hook ? matcher) { inherit (hook) matcher; }
    // lib.optionalAttrs (hook ? tools) { matcher = mkMatcher hook.tools; }
    // {
      hooks = [ (lib.filterAttrs (name: _: lib.elem name handlerFields) hook) ];
    };

  # ------------------------------------------------------------------------------------------------
  # Hook installation
  # ------------------------------------------------------------------------------------------------
  # Codex trusts a hook by hashing its event, matcher, and handler, command included. Commands name
  # stable links, which each activation repoints, so a rebuild that changes only a script keeps the
  # hook's hash.
  install =
    requested:
    let
      hooks = lib.filter (hook: hook.usesGateway or false -> enableCorpGateway) requested;
      commandHooks = lib.filter (hook: hook.type == "command") hooks;
      link = hook: "llm-assistants/hooks/${lib.unsafeDiscardStringContext (baseNameOf hook.command)}";
      linked = map (
        hook: if hook.type == "command" then hook // { command = "${dataHome}/${link hook}"; } else hook
      ) hooks;
    in
    {
      events = lib.mapAttrs (_: map mkEntry) (lib.groupBy (hook: hook.event) linked);

      dataFiles = lib.listToAttrs (
        map (hook: lib.nameValuePair (link hook) { source = hook.command; }) commandHooks
      );
    };
in
{
  inherit
    install
    mkNuHook
    timeouts
    ;

  hooks = {
    autoFormat = import ./auto-format {
      inherit
        fileFormatter
        mkNuHook
        patchInput
        timeouts
        ;
    };

    commentGate = import ./comment-gate {
      inherit
        mkNuHook
        timeouts
        modelCall
        modelCatalog
        promptFragments
        patchInput
        ;
    };

    completeness = import ./completeness { inherit timeouts; };
  };
}
