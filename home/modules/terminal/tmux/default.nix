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
  inherit (pkgs.stdenv) isDarwin;

  # Local clipboard sink, or null when only OSC 52 is reachable (headless servers
  # over SSH have no local clipboard). Both local sinks dodge Cursor's xterm.js
  # OSC 52 decoder, which double-encodes multibyte UTF-8. clip.exe needs
  # UTF-16LE because it otherwise decodes stdin as the Windows ANSI codepage.
  localClipboard =
    if isDarwin then
      "pbcopy"
    else if config.hakula.wsl.enable then
      "iconv -f UTF-8 -t UTF-16LE | clip.exe"
    else
      null;

  # A local sink means tmux's own OSC 52 emission must be off so it can't race
  # the pipe; without one, OSC 52 is the only route to the clipboard.
  clipboardConfig =
    if localClipboard != null then
      ''
        set -s set-clipboard off
        bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel ${lib.escapeShellArg localClipboard}
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
