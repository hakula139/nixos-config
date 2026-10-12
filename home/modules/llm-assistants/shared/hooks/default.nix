# ==================================================================================================
# Shared Hooks
# ==================================================================================================
# Claude Code and Codex name their events alike, so a hook states its own event and only its tool
# classes need translating. Each adapter owns that map and hands it to `mkMatcher`.
# ==================================================================================================

{
  pkgs,
  lib,
  dataHome,
  modelCatalog,
  readPrompt,
  phrasing,
  repo,
  enableDevToolchains ? true,
}:

{
  assistant,
  gateway ? { },
}:

let
  json = pkgs.formats.json { };

  # ------------------------------------------------------------------------------------------------
  # Hook timeouts
  # ------------------------------------------------------------------------------------------------
  timeouts = {
    modelCall = 90;
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
        modelCatalog
        timeouts
        ;
    })
    modelCall
    ;

  # ------------------------------------------------------------------------------------------------
  # Hook installation
  # ------------------------------------------------------------------------------------------------
  # Codex trusts a hook by hashing its command, so a store path would need review after every
  # rebuild. Commands therefore name stable links, which each activation repoints.
  install =
    hooks:
    let
      commandHooks = lib.filter (hook: hook.type == "command") hooks;
      link = hook: "llm-assistants/hooks/${lib.unsafeDiscardStringContext (baseNameOf hook.command)}";
    in
    {
      hooks = map (
        hook: if hook.type == "command" then hook // { command = "${dataHome}/${link hook}"; } else hook
      ) hooks;

      dataFiles = lib.listToAttrs (
        map (hook: lib.nameValuePair (link hook) { source = hook.command; }) commandHooks
      );
    };

  # ------------------------------------------------------------------------------------------------
  # Tool matchers
  # ------------------------------------------------------------------------------------------------
  mkMatcher =
    toolClasses: hooks:
    lib.concatStringsSep "|" (
      lib.unique (
        lib.concatMap (
          hook:
          lib.concatMap (tool: if lib.hasPrefix "mcp__" tool then [ tool ] else toolClasses.${tool}) (
            hook.tools or [ ]
          )
        ) hooks
      )
    );
in
{
  inherit
    install
    mkMatcher
    mkNuHook
    timeouts
    ;

  hooks = {
    autoFormat = import ./auto-format {
      inherit
        pkgs
        lib
        enableDevToolchains
        mkNuHook
        patchInput
        repo
        timeouts
        ;
    };

    commentGate = import ./comment-gate {
      inherit
        mkNuHook
        modelCall
        patchInput
        readPrompt
        timeouts
        ;
    };

    completeness = import ./completeness;

    prosePolish = import ./prose-polish {
      inherit
        lib
        mkNuHook
        modelCall
        modelCatalog
        phrasing
        timeouts
        ;
    };
  };
}
