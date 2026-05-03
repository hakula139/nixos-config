# ==============================================================================
# Zsh Shell
# ==============================================================================

{
  config,
  pkgs,
  lib,
  isNixOS ? false,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin isLinux;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # --------------------------------------------------------------------------
    # History settings
    # --------------------------------------------------------------------------
    history = {
      size = 100000;
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
        name = "zsh-hist";
        src = pkgs.zsh-hist;
        file = "share/zsh-hist/zsh-hist.plugin.zsh";
      }
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
      # Trailing space enables alias expansion after sudo
      sudo = "sudo ";

      # Modern CLI replacements
      ls = "eza --icons --group-directories-first";
      l = "eza -1 --icons --group-directories-first";
      ll = "eza -l --icons --group-directories-first --git";
      la = "eza -la --icons --group-directories-first --git";
      lt = "eza --tree --icons --group-directories-first --level=2";
      cat = "bat --paging=never";
      grep = "grep --color=auto";

      # Disk usage
      df = "df -h";
      du = "du -h";
      dud = "du -d 1 -h";
      duf = "du -sh *";

      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";

      # Nix aliases
      nixup = "nix flake update";
      nixgc = "nh clean all --keep-since 7d";
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

      # Process management
      psg = "ps aux | grep -v grep | grep -i";

      # Network
      ports = "ss -tulanp";
      myip = "curl -s ifconfig.me";

      # Misc utilities
      path = ''echo "$PATH" | tr ':' '\n' | nl'';
      now = "date '+%Y-%m-%d %H:%M:%S'";
      week = "date +%V";
      h = "history";
      hg = "history | grep";
      c = "clear";
      q = "exit";

      # Zsh utilities
      zcp = "zmv -C";
      zln = "zmv -L";
      reload = "exec zsh";
    }
    # NixOS-specific aliases
    // lib.optionalAttrs isNixOS {
      # Nix aliases
      nixsw = "nh os switch .";
      nixtest = "nh os test .";
      nixboot = "nh os boot .";
      nixlist = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
      nixroll = "sudo nixos-rebuild switch --rollback --flake .";
    }
    # Generic Linux (non-NixOS) aliases
    // lib.optionalAttrs (isLinux && !isNixOS) {
      # Home Manager aliases
      nixsw = "nh home switch . -c hakula-linux";
      nixlist = "home-manager generations | head -n 10";
      nixroll = "home-manager switch --rollback";
    }
    # macOS-specific aliases
    // lib.optionalAttrs isDarwin {
      # Nix aliases
      nixsw = "nh darwin switch .";
      nixlist = "sudo darwin-rebuild --list-generations";
      nixroll = "sudo darwin-rebuild switch --rollback";

      # System aliases
      nproc = "sysctl -n hw.logicalcpu";

      # Clipboard
      pbc = "pbcopy";
      pbp = "pbpaste";

      # Flush DNS cache
      flushdns = "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder";
    };

    # --------------------------------------------------------------------------
    # Additional configuration
    # --------------------------------------------------------------------------
    initContent = lib.fileContents ./init.zsh;
  };
}
