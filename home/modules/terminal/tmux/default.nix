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
  clipboardConfig = import ./clipboard.nix { inherit config lib pkgs; };

  # Catppuccin sources tmux recursively. Run it in the background so the outer
  # config queue can drain instead of deadlocking during cold startup.
  catppuccinConfig = ''
    set -g @catppuccin_flavor "mocha"
    set -g @catppuccin_window_status_style "rounded"
    set -g @catppuccin_date_time_text " %H:%M"
    run-shell -b ${pkgs.tmuxPlugins.catppuccin.rtp}
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
