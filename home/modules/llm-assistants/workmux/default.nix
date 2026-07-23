# ==============================================================================
# Workmux Agent Orchestration
# ==============================================================================

{
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
    "open-pr"
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
  home.packages = [ workmux ];

  home.file = workmuxSkillFiles;

  programs.tmux.extraConfig = lib.mkBefore ''
    set -g @catppuccin_window_text " #T#{?@workmux_status, #{@workmux_status},}"
    set -g @catppuccin_window_current_text " #T#{?@workmux_status, #{@workmux_status},}"
    bind g display-popup -E -w 90% -h 90% '${workmux}/bin/workmux dashboard'
  '';

  xdg.configFile."workmux/config.yaml".source = configFile;
}
