{
  config,
  pkgs,
  lib,
  secrets,
  isNixOS ? false,
  isDesktop ? false,
  ...
}:

# ==============================================================================
# Cursor Configuration
# ==============================================================================

let
  cfg = config.hakula.cursor;
  isDarwin = pkgs.stdenv.isDarwin;

  settings = import ./settings.nix { inherit pkgs; };
  ext = import ./extensions.nix {
    inherit lib;
    prune = cfg.extensions.prune;
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
  };

  config = lib.mkIf cfg.enable (
    let
      mcp = import ./mcp.nix {
        inherit
          config
          pkgs
          lib
          secrets
          isNixOS
          isDesktop
          ;
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

      remoteFiles = {
        ".cursor-server/data/User/settings.json".source = settings.settingsJson;
        ".cursor-server/data/User/keybindings.json".source = ./keybindings.json;
        ".cursor-server/data/User/snippets".source = ./snippets;
      };
    in
    lib.mkMerge [
      mcp.secrets
      {
        # ------------------------------------------------------------------------
        # User configuration files
        # ------------------------------------------------------------------------
        home.file = {
          ".cursor/mcp.json".source = mcp.mcpJson;
        }
        // (lib.optionalAttrs (isDesktop && isDarwin) darwinFiles)
        // (lib.optionalAttrs (!isDesktop) remoteFiles);

        xdg.configFile = lib.optionalAttrs (isDesktop && !isDarwin) linuxFiles;

        # ------------------------------------------------------------------------
        # Extension management
        # ------------------------------------------------------------------------
        home.activation.cursorExtensions = lib.mkIf cfg.extensions.enable (
          let
            homeDir = config.home.homeDirectory;
            username = config.home.username;
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
