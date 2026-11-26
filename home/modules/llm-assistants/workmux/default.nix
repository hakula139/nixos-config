# ==================================================================================================
# Workmux Agent Orchestration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  yaml = pkgs.formats.yaml { };

  configFile = yaml.generate "workmux-config.yaml" {
    nerdfont = true;
    # Catppuccin owns the window format, and the tmux options below add Workmux's status.
    status_format = false;
    # activity-report's excluded_dirs recognizes Workmux workers by this prefix.
    worktree_prefix = "workmux-";
  };

  workmuxSkills = [
    "coordinator"
    "merge"
    "rebase"
    "workmux"
    "worktree"
  ];

  workmuxSkillFiles = lib.genAttrs' workmuxSkills (
    name:
    lib.nameValuePair ".agents/skills/${name}" {
      source = "${pkgs.workmux}/share/skills/workmux/${name}";
    }
  );
in
lib.mkIf config.hakula.llm-assistants.enable {
  # ------------------------------------------------------------------------------------------------
  # Packages
  # ------------------------------------------------------------------------------------------------
  home.packages = [
    pkgs.workmux
  ];

  # ------------------------------------------------------------------------------------------------
  # Agent resources
  # ------------------------------------------------------------------------------------------------
  home.file = workmuxSkillFiles // {
    ".omp/agent/extensions/workmux-status.ts".source =
      "${pkgs.workmux.src}/resources/omp/extensions/workmux-status.ts";
  };

  # ------------------------------------------------------------------------------------------------
  # tmux integration
  # ------------------------------------------------------------------------------------------------
  programs.tmux.extraConfig = lib.mkBefore ''
    set -ag @catppuccin_window_text "#{?@workmux_status, #{@workmux_status},}"
    set -ag @catppuccin_window_current_text "#{?@workmux_status, #{@workmux_status},}"
    bind g display-popup -EE -w 90% -h 90% 'workmux dashboard'
  '';

  # ------------------------------------------------------------------------------------------------
  # Program configuration
  # ------------------------------------------------------------------------------------------------
  xdg.configFile."workmux/config.yaml".source = configFile;
}
