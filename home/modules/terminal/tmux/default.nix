# ==================================================================================================
# tmux (Terminal Multiplexer)
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  ...
}:

let
  esc = lib.escapeShellArg;

  wrapper = pkgs.writeShellScript "tmux-wrapper" (
    builtins.replaceStrings
      [ "@direnv@" "@tmux@" ]
      [ (esc (lib.getExe config.programs.direnv.package)) (esc (lib.getExe pkgs.tmux)) ]
      (builtins.readFile ./wrapper.sh)
  );

  # A custom join keeps the man output, which wrap-package would drop.
  tmuxBin = pkgs.symlinkJoin {
    inherit (pkgs.tmux) name;
    paths = [
      pkgs.tmux
      pkgs.tmux.man
    ];

    postBuild = ''
      rm "$out/bin/tmux"
      ln -s ${esc wrapper} "$out/bin/tmux"
    '';

    meta.mainProgram = "tmux";
  };

  taskName = pkgs.writers.writeNuBin "tmux-task-name" {
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [ pkgs.tmux ])
    ];
  } (builtins.readFile ./task-name.nu);

  # The plugin wrapper starts nested tmux clients, which deadlock in the config queue when
  # synchronous and can be interrupted midway when backgrounded.
  catppuccinPluginDir = "${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin";
  catppuccinConfig = ''
    set -g @catppuccin_flavor "mocha"
    set -g @catppuccin_window_status_style "rounded"
    set -g @catppuccin_date_time_text " %H:%M"
    source-file ${catppuccinPluginDir}/catppuccin_options_tmux.conf
    source-file ${catppuccinPluginDir}/catppuccin_tmux.conf

    set -gF message-style "fg=#{@thm_teal},bg=terminal,fill=terminal"
    set -gF message-command-style "fg=#{@thm_teal},bg=terminal,fill=terminal"
  '';

  nushellConfig = ''
    bind C-n split-window -h -c "#{pane_current_path}" "${lib.getExe pkgs.nushell}"
    bind N new-window -c "#{pane_current_path}" "${lib.getExe pkgs.nushell}"
  '';

  # Other sockets, such as `tmux -L <name>` test servers, must not restore or overwrite the saved
  # sessions, and Continuum's own check never sees other servers because `ps` shows tmux by its
  # store path. Continuum must inject its save command after the final status-right assignment.
  persistenceConfig = ''
    %if "#{==:#{b:socket_path},default}"
    set -g @resurrect-capture-pane-contents "on"
    run-shell ${pkgs.tmuxPlugins.resurrect.rtp}

    set -g @continuum-restore "on"
    set -g @continuum-save-interval "10"
    run-shell ${pkgs.tmuxPlugins.continuum.rtp}
    %endif
  '';
in
{
  home.packages = [ taskName ];

  programs.tmux = {
    enable = true;
    package = tmuxBin;

    # ----------------------------------------------------------------------------------------------
    # Core settings
    # ----------------------------------------------------------------------------------------------
    baseIndex = 1;
    clock24 = true;
    disableConfirmationPrompt = true;
    escapeTime = 1;
    focusEvents = true;
    keyMode = "vi";
    mouse = true;
    prefix = "C-a";
    shell = lib.getExe pkgs.zsh;
    terminal = "tmux-256color";

    # ----------------------------------------------------------------------------------------------
    # Extra configuration
    # ----------------------------------------------------------------------------------------------
    extraConfig = lib.concatStringsSep "\n" [
      (lib.fileContents ./tmux.conf)
      nushellConfig
      catppuccinConfig
      persistenceConfig
    ];
  };
}
