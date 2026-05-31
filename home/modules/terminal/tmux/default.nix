# ==============================================================================
# tmux (Terminal Multiplexer)
# ==============================================================================

{
  pkgs,
  lib,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin;

  # Clipboard sink. macOS uses pbcopy directly because Cursor's xterm.js mangles
  # multibyte UTF-8 in OSC 52 payloads. Other platforms use OSC 52, which the
  # outer terminal forwards to its host clipboard.
  clipboardConfig =
    if isDarwin then
      ''
        set -s set-clipboard off
        bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel pbcopy
      ''
    else
      ''
        set -s set-clipboard on
        bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel
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
      # Color scheme
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor "mocha"
          set -g @catppuccin_window_status_style "rounded"
          set -g @catppuccin_date_time_text " %H:%M"
        '';
      }

      # Session persistence
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }

      # Auto-save sessions
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
    extraConfig = lib.fileContents ./tmux.conf + "\n\n" + clipboardConfig;
  };
}
