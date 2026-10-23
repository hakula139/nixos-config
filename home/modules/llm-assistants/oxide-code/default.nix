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
  cfg = config.hakula.oxide-code;
  shared = config.lib.llmAssistants;

  profiles = import ./profiles.nix {
    inherit
      config
      pkgs
      lib
      ;
    inherit (shared) profileDefinitions anthropicProfiles mkProfileSwitch;
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.oxide-code = {
    enable = lib.mkEnableOption "oxide-code";

    auth = profiles.options;

    proxy = repoLib.proxy.mkProxyOptions "oxide-code";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      toml = pkgs.formats.toml { };

      # --------------------------------------------------------------------------------------------
      # Package wrapper
      # --------------------------------------------------------------------------------------------
      wrapArgs =
        profiles.wrapArgs
        ++ lib.optionals cfg.proxy.enable [
          "--run"
          (repoLib.proxy.mkProxyScript cfg.proxy)
        ];

      oxBin = repoLib.wrapPackage {
        inherit pkgs wrapArgs;
        pkg = pkgs.oxide-code;
        bin = "ox";
      };

      # --------------------------------------------------------------------------------------------
      # Configuration files
      # --------------------------------------------------------------------------------------------
      configToml = toml.generate "ox-config.toml" {
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
    in
    lib.mkMerge [
      profiles.config

      {
        # ------------------------------------------------------------------------------------------
        # Packages
        # ------------------------------------------------------------------------------------------
        home.packages = [ oxBin ];

        # ------------------------------------------------------------------------------------------
        # Configuration files
        # ------------------------------------------------------------------------------------------
        xdg.configFile."ox/config.toml".source = configToml;
      }
    ]
  );
}
