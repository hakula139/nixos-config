# ==============================================================================
# Cursor Configuration
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpDomain,
  llmAssistantLib,
  proxyLib,
  secretPath,
  systemManagerLib,
  flakeConfigName ? null,
  hostName ? null,
  isNixOS ? false,
  isDesktop ? false,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin isLinux;
  cfg = config.hakula.cursor;

  inherit (llmAssistantLib) mcpOptions;
  cursorMcpServers = [
    "atlassian"
    "braveSearch"
    "deepwiki"
    "fetcher"
    "filesystem"
    "git"
    "github"
    "gitlab"
  ];

  settings = import ./settings.nix {
    inherit pkgs isDarwin isNixOS;
    inherit (cfg.nixd) flakePath;
    configName =
      if flakeConfigName != null then
        flakeConfigName
      else
        lib.toLower (if hostName != null then hostName else "wsl-non-nixos");
  };

  ext = import ./extensions.nix {
    inherit lib;
    inherit (cfg.extensions) prune;
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

    mcp = {
      enabledServers = mcpOptions.mkEnabledServersOption {
        names = cursorMcpServers;
        description = "MCP servers to enable";
      };
      disabledServers = mcpOptions.mkDisabledServersOption {
        description = "MCP servers to disable";
      };
    };

    nixd.flakePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Absolute path to the nixos-config flake for nixd completions";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      mcp = import ./mcp.nix {
        inherit
          config
          pkgs
          lib
          llmAssistantLib
          corpDomain
          proxyLib
          secretPath
          ;
        enabledServers = builtins.filter (s: !(lib.elem s cfg.mcp.disabledServers)) cfg.mcp.enabledServers;
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
