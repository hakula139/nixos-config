# ==============================================================================
# Workmux Agent Orchestration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (pkgs) workmux;

  yaml = pkgs.formats.yaml { };

  configFile = yaml.generate "workmux-config.yaml" {
    nerdfont = true;
    # Catppuccin owns the window format; tmux options below add Workmux's status.
    status_format = false;
  };

  workmuxSkills = [
    "coordinator"
    "merge"
    "rebase"
    "workmux"
    "worktree"
  ];

  workmuxSkillFiles = lib.listToAttrs (
    map (name: {
      name = ".agents/skills/${name}";
      value = {
        source = "${workmux}/share/workmux/skills/${name}";
        recursive = true;
      };
    }) workmuxSkills
  );
in
{
  # ----------------------------------------------------------------------------
  # Packages
  # ----------------------------------------------------------------------------
  home.packages = [ workmux ];

  # ----------------------------------------------------------------------------
  # Agent resources
  # ----------------------------------------------------------------------------
  home.file = lib.mkMerge [
    workmuxSkillFiles
    (lib.mkIf config.hakula.omp.enable {
      ".omp/agent/extensions/workmux-status.ts".source =
        "${workmux.src}/resources/omp/extensions/workmux-status.ts";
    })
  ];

  # ----------------------------------------------------------------------------
  # tmux integration
  # ----------------------------------------------------------------------------
  programs.tmux.extraConfig = lib.mkBefore ''
    set -g @catppuccin_window_text " #T#{?@workmux_status, #{@workmux_status},}"
    set -g @catppuccin_window_current_text " #T#{?@workmux_status, #{@workmux_status},}"
    bind g display-popup -E -w 90% -h 90% '${workmux}/bin/workmux dashboard'
  '';

  # ----------------------------------------------------------------------------
  # Program configuration
  # ----------------------------------------------------------------------------
  xdg.configFile."workmux/config.yaml".source = configFile;

  xdg.configFile."opencode/plugins/workmux-status.ts" = lib.mkIf config.hakula.opencode.enable {
    source = "${workmux.src}/resources/opencode/plugins/workmux-status.ts";
  };
}
