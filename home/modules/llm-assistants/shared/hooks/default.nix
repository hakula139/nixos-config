# ==================================================================================================
# Shared Hooks
# ==================================================================================================
# Claude Code and Codex name their events alike, so a hook states its own event and only its tool
# classes need translating. Each adapter owns that map and hands it to `mkHooks`.
# ==================================================================================================

{
  pkgs,
  lib,
  corpGateway,
  secretPath,
  dataHome,
  modelCatalog,
  readPrompt,
  phrasing,
  fileFormatter,
}:

{
  assistant,
  toolClasses,
  enableCorpGateway,
}:

let
  json = pkgs.formats.json { };

  gateway = {
    inherit (corpGateway) baseUrl;
    tokenFile = secretPath (corpGateway.tokenSecretFor assistant);
    caFile = secretPath corpGateway.caSecret;
  };

  # ------------------------------------------------------------------------------------------------
  # Hook timeouts
  # ------------------------------------------------------------------------------------------------
  timeouts = {
    modelConnect = 5;
    modelCall = 90;
    # A hook outlives its model calls by this much, so it can still report one that timed out.
    modelHookMargin = 10;
    tool = 10;
    # Auto-format runs `cargo clippy`, which may rebuild the crate after an edit.
    postEdit = 120;
  };

  # ------------------------------------------------------------------------------------------------
  # Hook generation
  # ------------------------------------------------------------------------------------------------
  mkNuHook =
    {
      slug,
      script,
      config,
    }:
    let
      configFile = json.generate "${assistant}-${slug}.json" config;
      package = pkgs.writers.writeNuBin "${assistant}-${slug}" {
        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath [ pkgs.coreutils ])

          "--add-flag"
          "${configFile}"
        ];
      } (builtins.readFile script);
    in
    lib.getExe package;

  patchInput = pkgs.writers.writeNu "patch-input" { } (
    builtins.readFile ./lib/patch-input/patch-input.nu
  );

  inherit
    (import ./lib/model-call {
      inherit
        pkgs
        lib
        gateway
        mkNuHook
        timeouts
        ;
    })
    modelCall
    ;

  # ------------------------------------------------------------------------------------------------
  # Hook entries
  # ------------------------------------------------------------------------------------------------
  mkMatcher =
    tools:
    lib.concatStringsSep "|" (
      lib.unique (
        lib.concatMap (tool: if lib.hasPrefix "mcp__" tool then [ tool ] else toolClasses.${tool}) tools
      )
    );

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
        readPrompt
        patchInput
        ;
    };

    completeness = import ./completeness { inherit timeouts; };

    prosePolish = import ./prose-polish {
      inherit
        lib
        mkNuHook
        timeouts
        modelCall
        modelCatalog
        phrasing
        ;
    };
  };
}
