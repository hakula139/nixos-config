{
  config,
  pkgs,
  lib,
  isNixOS,
  ...
}:

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in
{
  # ============================================================================
  # Zsh Shell Configuration
  # ============================================================================
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # --------------------------------------------------------------------------
    # History Settings
    # --------------------------------------------------------------------------
    history = {
      size = 50000;
      save = 50000;
      path = "${config.xdg.dataHome}/zsh/history";
      extended = true;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      share = true;
    };

    historySubstringSearch.enable = true;
    autocd = true;

    # --------------------------------------------------------------------------
    # Oh My Zsh
    # --------------------------------------------------------------------------
    oh-my-zsh = {
      enable = true;
      plugins = [
        # Git
        "git"
        "git-lfs"
        "gitignore"

        # Containers & Kubernetes
        "docker"
        "docker-compose"
        "podman"
        "kubectl"
        "helm"

        # Python
        "pip"
        "poetry"

        # Files & Archives
        "rsync"
        "extract"

        # Utilities
        "sudo"
        "encode64"
        "copypath"
        "dirhistory"
        "colored-man-pages"
      ]
      # Linux-only plugins
      ++ lib.optionals isLinux [
        "systemd"
      ]
      # macOS-only plugins
      ++ lib.optionals isDarwin [
        "brew"
        "macos"
      ];
    };

    # --------------------------------------------------------------------------
    # Zsh Plugins (from nixpkgs)
    # --------------------------------------------------------------------------
    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];

    # --------------------------------------------------------------------------
    # Shell Aliases
    # --------------------------------------------------------------------------
    shellAliases = {
      # Modern CLI replacements
      ls = "eza --icons --group-directories-first";
      ll = "eza -l --icons --group-directories-first --git";
      la = "eza -la --icons --group-directories-first --git";
      lt = "eza --tree --icons --group-directories-first --level=2";
      cat = "bat --paging=never";
      grep = "grep --color=auto";

      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";

      # Nix aliases
      nixup = "nix flake update";
      nixgc = "nix-collect-garbage -d";
      nixopt = "nix-store --optimise";

      # Git extras
      gls = "git pull --recurse-submodules && git submodule foreach git lfs pull";

      # Podman Compose
      pcup = "podman-compose up";
      pcupb = "podman-compose up --build";
      pcupd = "podman-compose up -d";
      pcupdb = "podman-compose up -d --build";
      pcdn = "podman-compose down";
      pcpull = "podman-compose pull";
      pcr = "podman-compose run";

      # Docker Compose (v2): make OMZ docker-compose plugin aliases use `docker compose`
      docker-compose = "docker compose";

      # Kubectl extras
      kdelpf = "kubectl delete pod --field-selector=status.phase=Failed";
      kdelrs = "kubectl delete replicaset";

      # Python
      py = "python3";

      # Zsh utilities
      zcp = "zmv -C";
      zln = "zmv -L";
    }
    # NixOS-specific aliases
    // lib.optionalAttrs isNixOS {
      # Nix aliases
      nixlist = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
      nixroll = "sudo nixos-rebuild switch --rollback";
    }
    # Generic Linux (non-NixOS) aliases
    // lib.optionalAttrs (isLinux && !isNixOS) {
      # Home Manager aliases
      nixlist = "home-manager generations | head -n 10";
      nixroll = "home-manager switch --rollback";
    }
    # macOS-specific aliases
    // lib.optionalAttrs isDarwin {
      # Nix aliases
      nixlist = "sudo darwin-rebuild --list-generations";
      nixroll = "sudo darwin-rebuild switch --rollback";

      # System aliases
      nproc = "sysctl -n hw.logicalcpu";
    };

    # --------------------------------------------------------------------------
    # Additional Zsh Configuration
    # --------------------------------------------------------------------------
    initContent = ''
      # Globbing options
      setopt GLOB_DOTS
      setopt NO_CASE_GLOB
      setopt NUMERIC_GLOB_SORT
      setopt EXTENDED_GLOB

      # Misc options
      setopt CORRECT
      setopt INTERACTIVE_COMMENTS
      setopt PUSHD_IGNORE_DUPS
      setopt PUSHD_SILENT

      # Completion styling
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
      zstyle ':completion:*' menu select
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"

      # Key bindings for history search
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
      bindkey '^P' history-substring-search-up
      bindkey '^N' history-substring-search-down

      # Load zmv for batch renaming
      autoload -U zmv

      # fzf-tab styling
      zstyle ':fzf-tab:*' fzf-flags --height=40% --layout=reverse --border
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
      zstyle ':fzf-tab:complete:ls:*' fzf-preview 'eza -1 --color=always $realpath'

      # Create directory and cd into it
      mkcd() { mkdir -p "$1" && cd "$1"; }

      # Set EDITOR based on available editors (cursor > code > nvim > vim)
      if command -v cursor &>/dev/null; then
        export EDITOR="cursor editor --wait"
      elif command -v code &>/dev/null; then
        export EDITOR="code --wait"
      elif command -v nvim &>/dev/null; then
        export EDITOR="nvim"
      else
        export EDITOR="vim"
      fi
      alias e="$EDITOR"

      sudoe() {
        SUDO_EDITOR="$EDITOR" sudo -e "$@"
      }

      # ------------------------------------------------------------------------
      # Nix rebuild aliases
      # ------------------------------------------------------------------------
      ${
        if isNixOS then
          ''
            nixsw() { sudo nixos-rebuild switch --flake ".#$1"; }
            nixtest() { sudo nixos-rebuild test --flake ".#$1"; }
            nixboot() { sudo nixos-rebuild boot --flake ".#$1"; }
          ''
        else if isLinux then
          ''
            nixsw() { home-manager switch --flake ".#''${1:-hakula-linux}" -b bak; }
          ''
        else
          ''
            nixsw() { sudo darwin-rebuild switch --flake ".#$1"; }
          ''
      }

      # Git retag - delete and recreate a tag
      git-retag() {
        local tag=$1
        if git tag | grep -q "^$tag$"; then
          git tag --delete "$tag"
          git push origin --delete "$tag"
        fi
        git tag "$tag"
        git push origin "$tag"
      }
      alias gtr="git-retag"
    '';
  };

  # ============================================================================
  # Git Configuration
  # ============================================================================
  programs.git.enable = true;

  # ============================================================================
  # Starship Prompt
  # ============================================================================
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      # Global settings
      add_newline = false;
      scan_timeout = 10;
      command_timeout = 2000;

      # Prompt format
      format = "$directory$git_branch$git_status$character";
      right_format = "$cmd_duration$cmake$golang$gradle$haskell$java$nodejs$python$rust$docker_context$helm$kubernetes$nix_shell$username$hostname$time";

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
      # Prompt Character
      # ------------------------------------------------------------------------
      character = {
        format = "$symbol ";
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold green)";
      };

      # ------------------------------------------------------------------------
      # Command Duration
      # ------------------------------------------------------------------------
      cmd_duration = {
        format = "[$duration]($style) ";
        style = "bold yellow";
        min_time = 2000;
        show_milliseconds = false;
      };

      # ------------------------------------------------------------------------
      # Language Environments
      # ------------------------------------------------------------------------
      python = {
        format = "[$symbol$virtualenv]($style) ";
        style = "bold yellow";
        symbol = " ";
        detect_extensions = [ ];
        detect_files = [ ];
        detect_folders = [ ];
      };

      nodejs = {
        format = "[$symbol$version]($style) ";
        style = "bold green";
        symbol = " ";
        detect_extensions = [ ];
        detect_files = [ "package.json" ];
        detect_folders = [ "node_modules" ];
      };

      # ------------------------------------------------------------------------
      # Development Languages
      # ------------------------------------------------------------------------
      cmake = {
        format = "[$symbol$version]($style) ";
        style = "bold blue";
        symbol = "△ ";
      };

      golang = {
        format = "[$symbol$version]($style) ";
        style = "bold cyan";
        symbol = " ";
      };

      gradle = {
        format = "[$symbol$version]($style) ";
        style = "bold green";
        symbol = " ";
      };

      haskell = {
        format = "[$symbol$version]($style) ";
        style = "bold purple";
        symbol = " ";
      };

      java = {
        format = "[$symbol$version]($style) ";
        style = "bold red";
        symbol = " ";
      };

      rust = {
        format = "[$symbol$version]($style) ";
        style = "bold red";
        symbol = " ";
      };

      # ------------------------------------------------------------------------
      # Cloud & Containers
      # ------------------------------------------------------------------------
      docker_context = {
        format = "[$symbol$context]($style) ";
        style = "bold blue";
        symbol = " ";
        only_with_files = false;
      };

      helm = {
        format = "[$symbol$version]($style) ";
        style = "bold white";
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
        format = "[$symbol$state( \\($name\\))]($style) ";
        style = "bold blue";
        symbol = " ";
        impure_msg = "";
        pure_msg = "pure";
      };

      # ------------------------------------------------------------------------
      # SSH Context
      # ------------------------------------------------------------------------
      username = {
        format = "[$user]($style)";
        style_user = "dimmed white";
        style_root = "bold red";
        show_always = false;
      };

      hostname = {
        format = "@[$hostname]($style) ";
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
      # Disabled Modules
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

  # ============================================================================
  # FZF - Fuzzy Finder
  # ============================================================================
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height=40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
    ];
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
    historyWidgetOptions = [
      "--sort"
      "--exact"
    ];
  };

  # ============================================================================
  # Zoxide - Smarter cd command
  # ============================================================================
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [
      "--cmd"
      "j"
    ];
  };

  # ============================================================================
  # Direnv - Auto-load .envrc per directory
  # ============================================================================
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # ============================================================================
  # Neovim
  # ============================================================================
  programs.neovim = {
    enable = true;
    vimAlias = true;
    viAlias = true;
  };

  # ============================================================================
  # Additional CLI Tools
  # ============================================================================
  programs.jq.enable = true;
  programs.btop.enable = true;
}
