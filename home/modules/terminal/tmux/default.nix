# ==============================================================================
# tmux (Terminal Multiplexer)
# ==============================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  clipboardConfig = import ./clipboard.nix { inherit config pkgs lib; };

  # The plugin wrapper starts nested tmux clients, which deadlock in the config
  # queue when synchronous and can be interrupted midway when backgrounded.
  catppuccinPluginDir = "${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin";
  catppuccinConfig = ''
    set -g @catppuccin_flavor "mocha"
    set -g @catppuccin_window_status_style "rounded"
    set -g @catppuccin_date_time_text " %H:%M"
    source-file ${catppuccinPluginDir}/catppuccin_options_tmux.conf
    source-file ${catppuccinPluginDir}/catppuccin_tmux.conf
  '';
in
{
  programs.tmux = {
    enable = true;

    # --------------------------------------------------------------------------
    # Core settings
    # --------------------------------------------------------------------------
    baseIndex = 1;
    clock24 = true;
    disableConfirmationPrompt = true;
    escapeTime = 1;
    focusEvents = true;
    keyMode = "vi";
    mouse = true;
    prefix = "C-a";
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "tmux-256color";

    # --------------------------------------------------------------------------
    # Plugins
    # --------------------------------------------------------------------------
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }

      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '10'
        '';
      }
    ];

    # --------------------------------------------------------------------------
    # Extra configuration
    # --------------------------------------------------------------------------
    extraConfig = lib.concatStringsSep "\n" [
      (lib.fileContents ./tmux.conf)
      clipboardConfig
      catppuccinConfig
    ];
  };
}
