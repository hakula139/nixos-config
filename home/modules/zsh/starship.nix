# ==============================================================================
# Starship (Shell Prompt)
# ==============================================================================

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      # ------------------------------------------------------------------------
      # Global settings
      # ------------------------------------------------------------------------
      add_newline = false;
      scan_timeout = 10;
      command_timeout = 3000;

      # ------------------------------------------------------------------------
      # Prompt format
      # ------------------------------------------------------------------------
      format = "$directory$git_branch$git_status$character";
      right_format = "$cmd_duration$cmake$golang$gradle$haskell$java$nodejs$python$rust$docker_context$helm$kubernetes$nix_shell($username(@$hostname) )$time";

      # ------------------------------------------------------------------------
      # Directory
      # ------------------------------------------------------------------------
      directory = {
        format = "[$path]($style)[$read_only]($read_only_style) ";
        style = "bold blue";
        truncation_length = 3;
        truncate_to_repo = true;
        read_only = " ";
      };

      # ------------------------------------------------------------------------
      # Git
      # ------------------------------------------------------------------------
      git_branch = {
        format = "[$symbol$branch(:$remote_branch)]($style)";
        style = "green";
        symbol = "";
      };

      git_status = {
        format = "([$all_status$ahead_behind]($style)) ";
        style = "yellow";
        ahead = " ⇡$count";
        behind = " ⇣$count";
        diverged = " ⇕⇡$ahead_count⇣$behind_count";
        conflicted = " =$count";
        deleted = " ✘$count";
        modified = " !$count";
        renamed = " »$count";
        staged = " +$count";
        stashed = " *$count";
        untracked = " ?$count";
      };

      # ------------------------------------------------------------------------
      # Prompt character
      # ------------------------------------------------------------------------
      character = {
        format = "$symbol ";
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold green)";
      };

      # ------------------------------------------------------------------------
      # Command duration
      # ------------------------------------------------------------------------
      cmd_duration = {
        format = "[$duration]($style) ";
        style = "bold yellow";
        min_time = 2000;
        show_milliseconds = false;
      };

      # ------------------------------------------------------------------------
      # Language environments
      # ------------------------------------------------------------------------
      python = {
        format = "[$symbol$virtualenv]($style) ";
        style = "yellow";
        symbol = " ";
        detect_extensions = [ ];
        detect_files = [ ];
        detect_folders = [ ];
      };

      nodejs = {
        format = "[$symbol$version]($style) ";
        style = "green";
        symbol = " ";
        detect_extensions = [ ];
        detect_files = [ "package.json" ];
        detect_folders = [ "node_modules" ];
      };

      # ------------------------------------------------------------------------
      # Development languages
      # ------------------------------------------------------------------------
      cmake = {
        format = "[$symbol$version]($style) ";
        style = "blue";
        symbol = "△ ";
      };

      golang = {
        format = "[$symbol$version]($style) ";
        style = "cyan";
        symbol = " ";
      };

      gradle = {
        format = "[$symbol$version]($style) ";
        style = "green";
        symbol = " ";
      };

      haskell = {
        format = "[$symbol$version]($style) ";
        style = "purple";
        symbol = " ";
      };

      java = {
        format = "[$symbol$version]($style) ";
        style = "red";
        symbol = " ";
      };

      rust = {
        format = "[$symbol$version]($style) ";
        style = "red";
        symbol = " ";
      };

      # ------------------------------------------------------------------------
      # Cloud & Containers
      # ------------------------------------------------------------------------
      docker_context = {
        format = "[$symbol$context]($style) ";
        style = "bold blue";
        symbol = " ";
        only_with_files = false;
      };

      helm = {
        format = "[$symbol$version]($style) ";
        style = "white";
        symbol = "⎈ ";
      };

      kubernetes = {
        format = "[$symbol$context( \\($namespace\\))]($style) ";
        style = "bold cyan";
        symbol = "☸ ";
        disabled = false;
        detect_files = [ ];
        detect_folders = [ ];
        detect_env_vars = [ "KUBECONFIG" ];
        contexts = [
          {
            context_pattern = ".*prod.*";
            style = "bold red";
          }
          {
            context_pattern = ".*stag.*";
            style = "bold yellow";
          }
        ];
      };

      nix_shell = {
        format = "[$symbol($state )(\\($name\\))]($style) ";
        style = "bold blue";
        symbol = " ";
        impure_msg = "";
        pure_msg = "pure";
      };

      # ------------------------------------------------------------------------
      # SSH context
      # ------------------------------------------------------------------------
      username = {
        format = "[$user]($style)";
        style_user = "dimmed white";
        style_root = "bold red";
        show_always = false;
      };

      hostname = {
        format = "[$hostname]($style)";
        style = "dimmed white";
        ssh_only = true;
      };

      # ------------------------------------------------------------------------
      # Time
      # ------------------------------------------------------------------------
      time = {
        format = "[$time]($style)";
        style = "dimmed white";
        time_format = "%H:%M";
        disabled = false;
      };

      # ------------------------------------------------------------------------
      # Disabled modules
      # ------------------------------------------------------------------------
      aws.disabled = true;
      azure.disabled = true;
      cobol.disabled = true;
      crystal.disabled = true;
      dart.disabled = true;
      deno.disabled = true;
      dotnet.disabled = true;
      elixir.disabled = true;
      elm.disabled = true;
      erlang.disabled = true;
      gcloud.disabled = true;
      julia.disabled = true;
      kotlin.disabled = true;
      lua.disabled = true;
      nim.disabled = true;
      ocaml.disabled = true;
      opa.disabled = true;
      package.disabled = true;
      perl.disabled = true;
      php.disabled = true;
      pulumi.disabled = true;
      purescript.disabled = true;
      raku.disabled = true;
      red.disabled = true;
      ruby.disabled = true;
      scala.disabled = true;
      solidity.disabled = true;
      spack.disabled = true;
      swift.disabled = true;
      terraform.disabled = true;
      vagrant.disabled = true;
      vlang.disabled = true;
      zig.disabled = true;
    };
  };
}
