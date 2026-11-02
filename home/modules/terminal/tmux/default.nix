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

  # The plugin wrapper starts nested tmux clients, which deadlock the config queue if the initial
  # client exits while they run synchronously, and can be interrupted midway when backgrounded.
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
  # store path. Like Catppuccin's, their wrappers re-enter through nested clients, so this sets
  # their options, bindings, and save hook directly, after the final status-right assignment. The
  # fresh-server timestamp holds off the first autosave, which would otherwise replace the snapshot
  # the background restore reads.
  resurrectPluginDir = "${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect";
  continuumPluginDir = "${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum";
  restoreClients = pkgs.writers.writeNuBin "tmux-restore-clients" {
    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [ pkgs.tmux ])

      "--add-flag"
      "${continuumPluginDir}/scripts/continuum_restore.sh"
    ];
  } (builtins.readFile ./restore-clients.nu);

  persistenceConfig = ''
    %if "#{==:#{b:socket_path},default}"
    set -g @resurrect-capture-pane-contents "on"
    set -g @resurrect-save-script-path "${resurrectPluginDir}/scripts/save.sh"
    set -g @resurrect-restore-script-path "${resurrectPluginDir}/scripts/restore.sh"
    bind C-s run-shell "${resurrectPluginDir}/scripts/save.sh"
    bind C-r run-shell "${resurrectPluginDir}/scripts/restore.sh"

    set -g @continuum-restore "on"
    set -g @continuum-save-interval "10"
    set -ag status-right "#(${continuumPluginDir}/scripts/continuum_save.sh)"
    %if "#{==:#{server_sessions},0}"
    set -gF @continuum-save-last-timestamp "#{start_time}"
    run-shell -b ${restoreClients}/bin/tmux-restore-clients
    %endif
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
