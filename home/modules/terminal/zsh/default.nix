# ==============================================================================
# Zsh Shell
# ==============================================================================

{
  config,
  pkgs,
  lib,
  flakeConfigName,
  username ? "hakula",
  isNixOS ? false,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin isLinux;

  smProfile = "/nix/var/nix/profiles/system-manager-profiles";
  smHealthCheck = "system-manager-health-check agenix-install-secrets.service home-manager-${username}.service";

  # Re-sync side effects that depend on WSL interop. Empty on hosts without it.
  postSwitchCommands = lib.concatStringsSep "\n" (
    lib.optional config.hakula.fonts.windowsSync.enable "install-windows-fonts"
    ++ lib.optional config.hakula.cursor.windowsSync.enable "sync-windows-cursor-settings"
  );
  hasPostSwitchCommands = postSwitchCommands != "";

  nixosNixswCommand = "nh os switch '.#${flakeConfigName}'";
  nixosNixrollCommand = "sudo nixos-rebuild switch --rollback --flake '.#${flakeConfigName}'";

  # nixsw / nixroll run in the user's interactive shell so post-switch
  # commands have a live WSL_INTEROP socket.
  nixosNixswScript = pkgs.writeShellScript "nixsw" ''
    set -euo pipefail
    ${nixosNixswCommand}
    ${postSwitchCommands}
  '';

  nixosNixrollScript = pkgs.writeShellScript "nixroll" ''
    set -euo pipefail
    ${nixosNixrollCommand}
    ${postSwitchCommands}
  '';

  nixswScript = pkgs.writeShellScript "nixsw" ''
    set -euo pipefail
    system-manager switch --flake '.#${flakeConfigName}' --sudo
    ${smHealthCheck}
    ${postSwitchCommands}
  '';

  nixrollScript = pkgs.writeShellScript "nixroll" ''
    set -euo pipefail
    sudo nix-env --profile ${smProfile} --rollback
    system-manager activate --sudo
    ${smHealthCheck}
    ${postSwitchCommands}
  '';
in
{
  programs.zsh = {
    enable = true;
    dotDir = config.home.homeDirectory;
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
    // lib.optionalAttrs isNixOS {
      # Nix aliases
      nixlist = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
    }
    // lib.optionalAttrs (isNixOS && flakeConfigName != null) {
      # Aliases that target a flake attribute. Skipped on images like devvm
      # that have no nixosConfigurations entry to switch to.
      nixsw = if hasPostSwitchCommands then "${nixosNixswScript}" else nixosNixswCommand;
      nixtest = "nh os test '.#${flakeConfigName}'";
      nixboot = "nh os boot '.#${flakeConfigName}'";
      nixroll = if hasPostSwitchCommands then "${nixosNixrollScript}" else nixosNixrollCommand;
    }
    // lib.optionalAttrs (isLinux && !isNixOS) {
      # Nix aliases
      nixsw = "${nixswScript}";
      nixroll = "${nixrollScript}";
      nixlist = "sudo nix-env --profile ${smProfile} --list-generations";
    }
    // lib.optionalAttrs isDarwin {
      # Nix aliases
      nixsw = "nh darwin switch '.#${flakeConfigName}'";
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
