# ==============================================================================
# Workmux Agent Orchestration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  cfg = config.hakula.workmux;
  yaml = pkgs.formats.yaml { };

  configFile = yaml.generate "workmux-config.yaml" {
    nerdfont = true;
    # Catppuccin owns the window format; tmux options below add Workmux's status.
    status_format = false;
  };

  workmuxSkills = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir "${cfg.package.src}/skills")
  );

  workmuxSkillFiles = lib.listToAttrs (
    map (name: {
      name = ".agents/skills/${name}";
      value = {
        source = "${cfg.package}/share/workmux/skills/${name}";
        recursive = true;
      };
    }) workmuxSkills
  );
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.workmux = {
    enable = lib.mkEnableOption "Workmux agent worktree orchestration";

    package = lib.mkOption {
      type = lib.types.package;
      default = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.workmux;
      description = "Workmux package to use";
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file = workmuxSkillFiles;

    programs.tmux.extraConfig = lib.mkBefore ''
      set -g @catppuccin_window_text " #T#{?@workmux_status, #{@workmux_status},}"
      set -g @catppuccin_window_current_text " #T#{?@workmux_status, #{@workmux_status},}"
      bind g display-popup -E -w 90% -h 90% '${cfg.package}/bin/workmux dashboard'
    '';

    xdg.configFile."workmux/config.yaml".source = configFile;
  };
}
