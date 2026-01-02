{
  config,
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Cursor Configuration
# ==============================================================================

let
  cfg = config.hakula.cursor;
  isDarwin = pkgs.stdenv.isDarwin;

  ext = import ./extensions.nix { inherit lib; };
  mcp = import ./mcp.nix;
  settings = import ./settings.nix { inherit pkgs; };

  # ----------------------------------------------------------------------------
  # Cursor Paths
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
  # ============================================================================
  # Module Options
  # ============================================================================
  options.hakula.cursor = {
    enable = lib.mkEnableOption "Cursor configuration";

    enableExtensions = lib.mkEnableOption "Cursor extensions";
  };

  # ============================================================================
  # Module Configuration
  # ============================================================================
  config = lib.mkIf cfg.enable (
    let
      # `mcp.nix` depends on `config.age.secrets.*`, so keep evaluation inside
      # `mkIf cfg.enable` to avoid forcing it when Cursor is disabled.
      mcpJson = (mcp { inherit config pkgs; }).mcpJson;

      darwinXdgFiles = {
        "Library/Application Support/Cursor/User/settings.json".source = settings.settingsJson;
        "Library/Application Support/Cursor/User/keybindings.json".source = ./keybindings.json;
        "Library/Application Support/Cursor/User/snippets".source = ./snippets;
      };

      linuxXdgFiles = {
        "Cursor/User/settings.json".source = settings.settingsJson;
        "Cursor/User/keybindings.json".source = ./keybindings.json;
        "Cursor/User/snippets".source = ./snippets;
      };
    in
    {
      # --------------------------------------------------------------------------
      # Secrets (agenix)
      # --------------------------------------------------------------------------
      age.identityPaths = [
        "${config.home.homeDirectory}/.ssh/id_ed25519"
      ];

      age.secrets.brave-api-key = {
        file = ../../../secrets/shared/brave-api-key.age;
        path = "${config.home.homeDirectory}/.secrets/brave-api-key";
        mode = "0400";
      };

      age.secrets.context7-api-key = {
        file = ../../../secrets/shared/context7-api-key.age;
        path = "${config.home.homeDirectory}/.secrets/context7-api-key";
        mode = "0400";
      };

      home.activation.secretsDir = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        install -d -m 0700 "$HOME/.secrets"
      '';

      # --------------------------------------------------------------------------
      # User Configuration Files
      # --------------------------------------------------------------------------
      home.file = {
        ".cursor/mcp.json".source = mcpJson;
      }
      // (lib.optionalAttrs isDarwin darwinXdgFiles);

      xdg.configFile = lib.optionalAttrs (!isDarwin) linuxXdgFiles;

      # --------------------------------------------------------------------------
      # Extension Management
      # --------------------------------------------------------------------------
      home.activation.cursorExtensions = lib.mkIf cfg.enableExtensions (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          export PATH="${lib.concatStringsSep ":" paths}:$PATH"

          if command -v cursor &>/dev/null; then
            ${ext.installScript}
          else
            echo "Cursor not found, skipping extension installation"
          fi
        ''
      );
    }
  );
}
