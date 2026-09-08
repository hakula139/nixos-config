# ==============================================================================
# Shared Hooks
# ==============================================================================
# Claude Code and Codex name their events alike, so a hook states its own event
# and only its tool classes need translating. Each adapter owns that map and
# hands it to `mkMatcher`.
# ==============================================================================

{
  pkgs,
  lib,
  repo,
  enableDevToolchains ? true,
  ...
}:

{
  assistant,
  gateway ? { },
}:

let
  instructions = import ../instructions;

  # ----------------------------------------------------------------------------
  # Hook timeouts
  # ----------------------------------------------------------------------------
  timeouts = rec {
    modelCall = 90;
    tool = 10;
    postEdit = 3 * tool;
  };

  # ----------------------------------------------------------------------------
  # Hook generation
  # ----------------------------------------------------------------------------
  mkNuHook =
    {
      slug,
      script,
      config,
    }:
    let
      configFile = pkgs.writeText "${assistant}-${slug}.json" (builtins.toJSON config);
      package = pkgs.writers.writeNuBin "${assistant}-${slug}" {
        makeWrapperArgs = [
          "--add-flag"
          "${configFile}"
        ];
      } (builtins.readFile script);
    in
    "${package}/bin/${assistant}-${slug}";

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

  # ----------------------------------------------------------------------------
  # Tool matchers
  # ----------------------------------------------------------------------------
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
  inherit mkMatcher timeouts;

  hooks = {
    autoFormat = import ./auto-format {
      inherit
        pkgs
        lib
        enableDevToolchains
        mkNuHook
        patchInput
        repo
        ;
    };

    commentGate = import ./comment-gate {
      inherit
        mkNuHook
        modelCall
        patchInput
        timeouts
        ;
      inherit (instructions) commentGate;
    };

    completeness = import ./completeness;

    prosePolish = import ./prose-polish {
      inherit mkNuHook modelCall timeouts;
    };

    wakatime = import ./wakatime {
      inherit
        pkgs
        assistant
        mkNuHook
        timeouts
        ;
    };
  };
}
