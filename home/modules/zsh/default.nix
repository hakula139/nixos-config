{
  config,
  pkgs,
  lib,
  isNixOS ? false,
  ...
}:

# ==============================================================================
# Zsh Shell
# ==============================================================================

let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
in
{
  imports = [
    ./direnv.nix
    ./fzf.nix
    ./neovim.nix
    ./starship.nix
    ./tools.nix
    ./zoxide.nix
  ];

  config.programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # --------------------------------------------------------------------------
    # History settings
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

        # Archive & Compression
        "extract"

        # Python
        "pip"
        "poetry"

        # Containers & Kubernetes
        "docker"
        "docker-compose"
        "podman"
        "kubectl"
        "helm"

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
    # Plugins
    # --------------------------------------------------------------------------
    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
    ];

    # --------------------------------------------------------------------------
    # Shell aliases
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
    # Additional configuration
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
            nixsw() { home-manager switch --flake ".#$1" -b bak; }
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
}
