# ==================================================================================================
# oxide-code Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  ...
}:

let
  shared = config.lib.llmAssistants;

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      shared
      ;
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.oxide-code = {
    auth = profiles.options;
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf config.hakula.llm-assistants.enable (
    let
      # --------------------------------------------------------------------------------------------
      # Package wrapper
      # --------------------------------------------------------------------------------------------
      wrapArgs = profiles.wrapArgs ++ repoLib.proxy.mkProxyWrapArgs config.hakula.llm-assistants.proxy;

      oxBin = repoLib.wrapPackage {
        inherit pkgs wrapArgs;
        pkg = pkgs.oxide-code;
        bin = "ox";
      };
    in
    lib.mkMerge [
      profiles.config

      {
        # ------------------------------------------------------------------------------------------
        # Program configuration
        # ------------------------------------------------------------------------------------------
        home.packages = [
          oxBin
        ];

        programs.oxide-code = {
          enable = true;
          # Config checks cannot load the runtime auth profile. Keep its wrapper first in home.path.
          package = lib.lowPrio pkgs.oxide-code;

          settings = {
            permission.mode = "yolo";

            tui = {
              show_thinking = true;
              status_line = [
                "current-dir"
                "git-branch"
                "pull-request"
                "pull-request-checks"
                "model-with-effort"
                "context-used"
                "session-cost"
                "five-hour-limit"
                "weekly-limit"
                "task-progress"
                "run-state"
                "thread-title"
              ];
            };
          };
        };
      }
    ]
  );
}
