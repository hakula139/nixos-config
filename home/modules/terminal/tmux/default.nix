# ==============================================================================
# tmux (Terminal Multiplexer)
# ==============================================================================

{ pkgs, ... }:

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
    extraConfig = ''
      # True color support for modern terminals
      set -sa terminal-features ",xterm*:RGB"

      # Use OSC 52 escape sequences for system clipboard (works in WSL2, SSH,
      # macOS terminals, etc. without encoding issues unlike clip.exe / xclip)
      set -s set-clipboard on

      # Intuitive split keys
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # Pane navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Pane resizing
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Restore last-window
      bind Tab last-window

      # New windows inherit current path
      bind c new-window -c "#{pane_current_path}"

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; run-shell 'tmux display "Config reloaded"'

      # Vi copy-mode bindings (replaces tmux-yank plugin)
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      # Don't auto-copy on mouse drag release; require explicit yank (y)
      unbind -T copy-mode-vi MouseDragEnd1Pane

      # Mouse wheel: scroll 1 line at a time
      bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'copy-mode -e'"
      bind -T copy-mode-vi WheelUpPane select-pane \; send-keys -X scroll-up
      bind -T copy-mode-vi WheelDownPane select-pane \; send-keys -X scroll-down

      # Refresh env vars on reattach (prevents stale tokens and sockets)
      set -ga update-environment " VSCODE_GIT_ASKPASS_NODE"
      set -ga update-environment " VSCODE_GIT_ASKPASS_EXTRA_ARGS"
      set -ga update-environment " VSCODE_GIT_ASKPASS_MAIN"
      set -ga update-environment " VSCODE_GIT_IPC_HANDLE"
      set -ga update-environment " VSCODE_IPC_HOOK_CLI"
      set -ga update-environment " GIT_ASKPASS"
      set -ga update-environment " CLAUDE_CODE_SSE_PORT"
      set -ga update-environment " WSL_INTEROP"

      # Renumber windows when one is closed
      set -g renumber-windows on

      # Longer display time for pane indicators
      set -g display-panes-time 2000

      # Status bar
      set -g status-left-length 100
      set -g status-right-length 100
      set -g status-left "#{E:@catppuccin_status_session}"
      set -g status-right "#{E:@catppuccin_status_directory}"
      set -ag status-right "#{E:@catppuccin_status_host}"
      set -ag status-right "#{E:@catppuccin_status_date_time}"
    '';
  };
}
