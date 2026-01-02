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

  ext = import ./extensions.nix { inherit lib; };
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
      secretsDir = "${config.home.homeDirectory}/.secrets";
      mcp = import ./mcp.nix {
        inherit
          config
          pkgs
          isDesktop
          secretsDir
          ;
      };

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
      # On NixOS: system-level agenix handles decryption (modules/nixos/mcp)
      # On Darwin / standalone: home-manager agenix handles decryption
      # --------------------------------------------------------------------------
      age.identityPaths = lib.mkIf (!isNixOS) [
        "${config.home.homeDirectory}/.ssh/id_ed25519"
      ];

      age.secrets = lib.mkIf (!isNixOS) {
        brave-api-key = {
          file = ../../../secrets/shared/brave-api-key.age;
          path = "${secretsDir}/brave-api-key";
          mode = "0400";
        };

        context7-api-key = {
          file = ../../../secrets/shared/context7-api-key.age;
          path = "${secretsDir}/context7-api-key";
          mode = "0400";
        };
      };

      home.activation.secretsDir = lib.mkIf (!isNixOS) (
        lib.hm.dag.entryBefore [ "writeBoundary" ] ''
          install -d -m 0700 "${secretsDir}"
        ''
      );

      # --------------------------------------------------------------------------
      # User Configuration Files
      # --------------------------------------------------------------------------
      home.file = {
        ".cursor/mcp.json".source = mcp.mcpJson;
      }
      // (lib.optionalAttrs (isDesktop && isDarwin) darwinXdgFiles);

      xdg.configFile = lib.optionalAttrs (isDesktop && !isDarwin) linuxXdgFiles;

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
