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
  wrapper = pkgs.writeShellScript "tmux-wrapper" (
    builtins.replaceStrings
      [ "@direnv@" "@tmux@" ]
      [ (lib.getExe config.programs.direnv.package) (lib.getExe pkgs.tmux) ]
      (builtins.readFile ./wrapper.sh)
  );

  package = pkgs.symlinkJoin {
    inherit (pkgs.tmux) name;
    paths = [
      pkgs.tmux
      pkgs.tmux.man
    ];
    postBuild = ''
      rm "$out/bin/tmux"
      ln -s ${wrapper} "$out/bin/tmux"
    '';
  };

  # The plugin wrapper starts nested tmux clients, which deadlock in the config queue when
  # synchronous and can be interrupted midway when backgrounded.
  catppuccinPluginDir = "${pkgs.tmuxPlugins.catppuccin}/share/tmux-plugins/catppuccin";
  catppuccinConfig = ''
    set -g @catppuccin_flavor "mocha"
    set -g @catppuccin_window_status_style "rounded"
    set -g @catppuccin_date_time_text " %H:%M"
    source-file ${catppuccinPluginDir}/catppuccin_options_tmux.conf
    source-file ${catppuccinPluginDir}/catppuccin_tmux.conf
  '';

  # Continuum must inject its save command after the final status-right assignment.
  continuumConfig = ''
    set -g @continuum-restore "on"
    set -g @continuum-save-interval "10"
    run-shell ${pkgs.tmuxPlugins.continuum.rtp}
  '';

  nushellConfig = ''
    bind C-n split-window -h -c "#{pane_current_path}" "${lib.getExe pkgs.nushell}"
    bind N new-window -c "#{pane_current_path}" "${lib.getExe pkgs.nushell}"
  '';
in
{
  programs.tmux = {
    enable = true;
    inherit package;

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
    # Plugins
    # ----------------------------------------------------------------------------------------------
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents "on"
        '';
      }
    ];

    # ----------------------------------------------------------------------------------------------
    # Extra configuration
    # ----------------------------------------------------------------------------------------------
    extraConfig = lib.concatStringsSep "\n" [
      (lib.fileContents ./tmux.conf)
      nushellConfig
      catppuccinConfig
      continuumConfig
    ];
  };
}
