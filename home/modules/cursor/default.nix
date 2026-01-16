{
  config,
  pkgs,
  lib,
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
    inherit lib isDesktop;
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
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            cursor_server_path="$(
              ls -1d "$HOME/.cursor-server/bin/"*"/bin/remote-cli" 2>/dev/null | sort | tail -n 1 || true
            )"

            export PATH="${lib.concatStringsSep ":" paths}''${cursor_server_path:+:$cursor_server_path}:$PATH"

            if command -v cursor &>/dev/null; then
              ${ext.installScript}
            else
              echo "Cursor not found, skipping extension installation"
            fi
          ''
        );
      }
    ]
  );
}
