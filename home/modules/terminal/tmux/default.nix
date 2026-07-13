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
  # the pipe. Without one, OSC 52 is the only route to the clipboard.
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

  # Catppuccin's loader re-enters tmux with `tmux source`. A foreground run-shell
  # (what HM's plugins list emits) deadlocks the config queue on cold startup:
  # the nested client blocks on the not-yet-ready server, stranding every later
  # option and keybinding. `-b` backgrounds it so the queue drains first.
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
    # Catppuccin loads via extraConfig (not the plugins list) so its loader runs
    # backgrounded, and last so a stalled loader can't strand earlier config.
    extraConfig = lib.concatStringsSep "\n" [
      (lib.fileContents ./tmux.conf)
      clipboardConfig
      catppuccinConfig
    ];
  };
}
