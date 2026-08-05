# ==============================================================================
# Cursor Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  flakeConfigName,
  isDesktop ? false,
  isNixOS ? false,
  llmAssistantLib,
  proxyLib,
  secretPath,
  systemManagerLib,
  wslLib,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin isLinux;
  cfg = config.hakula.cursor;

  # ----------------------------------------------------------------------------
  # MCP
  # ----------------------------------------------------------------------------
  inherit (llmAssistantLib) mcpOptions;
  cursorMcpServers = mcpOptions.commonServerNames;

  # ----------------------------------------------------------------------------
  # Settings and extensions
  # ----------------------------------------------------------------------------
  settings = import ./settings {
    inherit
      pkgs
      flakeConfigName
      isDarwin
      isNixOS
      ;
    inherit (cfg.nixd) flakePath;
    inherit (config.home) profileDirectory;
  };

  ext = import ./extensions.nix {
    inherit lib;
    inherit (cfg.extensions) prune;
  };

  # ----------------------------------------------------------------------------
  # Windows sync
  # ----------------------------------------------------------------------------
  syncWindowsSettings =
    let
      syncScript = pkgs.copyPathToStore ./settings/sync-windows-settings.sh;
      windowsInterop = pkgs.copyPathToStore wslLib.windowsInteropScript;
    in
    pkgs.writeShellApplication {
      name = "sync-windows-cursor-settings";
      runtimeInputs = with pkgs; [
        coreutils
        diffutils
        jq
      ];
      text = ''
        exec ${pkgs.bash}/bin/bash ${syncScript} ${windowsInterop} ${settings.windowsSettingsJson}
      '';
    };

  # ----------------------------------------------------------------------------
  # Cursor paths
  # ----------------------------------------------------------------------------
  paths =
    if isDarwin then
      [
        "/usr/local/bin"
        "/Applications/Cursor.app/Contents/Resources/app/bin"
      ]
    else
      [
        "/usr/local/bin"
        "/usr/bin"
      ];
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options.hakula.cursor = {
    enable = lib.mkEnableOption "Cursor configuration";

    extensions = {
      enable = lib.mkEnableOption "Cursor extensions";
      prune = lib.mkEnableOption "Prune Cursor extensions not in the provisioned list";
    };

    windowsSync = {
      enable = lib.mkEnableOption "syncing Nix-managed Cursor settings to Windows (WSL only)";
    };

    mcp = mcpOptions.mkMcpOptions { names = cursorMcpServers; };

    nixd.flakePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Absolute path to the nixos-config flake for nixd completions";
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      mcp = import ./mcp.nix {
        inherit
          config
          pkgs
          lib
          llmAssistantLib
          corpHosts
          proxyLib
          secretPath
          ;
        enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
      };

      darwinFiles = {
        "Library/Application Support/Cursor/User/settings.json".source = settings.settingsJson;
        "Library/Application Support/Cursor/User/keybindings.json".source = ./keybindings.json;
        "Library/Application Support/Cursor/User/snippets".source = ./snippets;
      };

      linuxFiles = {
        "Cursor/User/settings.json".source = settings.settingsJson;
        "Cursor/User/keybindings.json".source = ./keybindings.json;
        "Cursor/User/snippets".source = ./snippets;
      };

      # Cursor's remote server starts with a clean environment and skips
      # zsh startup scripts, so prepend system-manager and Home Manager
      # paths here. Sourced before the server launches the extension host.
      serverEnvSetup = pkgs.writeText "cursor-server-env-setup" ''
        [ -r /etc/set-environment ] && . /etc/set-environment

        for p in ${
          lib.concatMapStringsSep " " (p: ''"${p}"'') (
            systemManagerLib.systemPaths ++ [ "$HOME/.nix-profile/bin" ]
          )
        }; do
          case ":$PATH:" in
            *":$p:"*) ;;
            *) [ -d "$p" ] && PATH="$p:$PATH" ;;
          esac
        done
        export PATH
      '';

      remoteFiles = {
        ".cursor-server/data/Machine/settings.json".source = settings.machineSettingsJson;
        ".cursor-server/server-env-setup".source = serverEnvSetup;
      };
    in
    lib.mkMerge [
      {
        # ----------------------------------------------------------------------
        # User configuration files
        # ----------------------------------------------------------------------
        home.packages = lib.optional cfg.windowsSync.enable syncWindowsSettings;

        home.file = {
          ".cursor/mcp.json".source = mcp.mcpJson;
        }
        // (lib.optionalAttrs (isDesktop && isDarwin) darwinFiles)
        // (lib.optionalAttrs isLinux remoteFiles);

        xdg.configFile = lib.optionalAttrs (isDesktop && !isDarwin) linuxFiles;

        # ----------------------------------------------------------------------
        # Extension management
        # ----------------------------------------------------------------------
        home.activation.cursorExtensions = lib.mkIf cfg.extensions.enable (
          let
            inherit (config.home) username;
            homeDir = config.home.homeDirectory;
          in
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            cursor_server_path="$(
              find "${homeDir}/.cursor-server/bin" -type d -name "remote-cli" 2>/dev/null | sort | tail -n 1 || true
            )"

            export PATH="${lib.concatStringsSep ":" paths}''${cursor_server_path:+:$cursor_server_path}:$PATH"

            # Detect Cursor IPC socket for CLI communication (needed when running via sudo)
            if [ -z "''${VSCODE_IPC_HOOK_CLI:-}" ]; then
              uid="$(id -u "${username}")"
              ipc_socket="$(ls -t /run/user/"$uid"/vscode-ipc-*.sock 2>/dev/null | head -1 || true)"
              if [ -n "$ipc_socket" ]; then
                export VSCODE_IPC_HOOK_CLI="$ipc_socket"
              fi
            fi

            if command -v cursor &>/dev/null; then
              (
                ${ext.installScript}
              ) || echo "Cursor extension management failed, continuing anyway"
            else
              echo "Cursor not found, skipping extension installation"
            fi
          ''
        );
      }
    ]
  );
}
