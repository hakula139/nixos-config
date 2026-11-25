# ==================================================================================================
# Zed Editor Settings
# ==================================================================================================

{
  pkgs,
  lib,
}:

let
  json = pkgs.formats.json { };

  # ------------------------------------------------------------------------------------------------
  # Extensions
  # ------------------------------------------------------------------------------------------------
  extensions = [
    "catppuccin"
    "catppuccin-icons"
    "csv"
    "docker-compose"
    "dockerfile"
    "haskell"
    "latex"
    "nix"
    "nu"
    "proto"
    "sql"
    "toml"
    "typst"
    "vue"
    "xml"
  ];

  # ------------------------------------------------------------------------------------------------
  # User settings
  # ------------------------------------------------------------------------------------------------
  userSettings = {
    base_keymap = "VSCode";

    theme = {
      mode = "system";
      light = "Catppuccin Latte";
      dark = "Catppuccin Mocha";
    };
    icon_theme = {
      mode = "system";
      light = "Catppuccin Latte";
      dark = "Catppuccin Mocha";
    };

    buffer_font_family = "Maple Mono NF CN";
    buffer_font_fallbacks = [ "Sarasa Mono SC" ];
    buffer_font_size = 16;

    tab_size = 2;
    autosave = "off";
    ensure_final_newline_on_save = false;
    format_on_save = "on";
    load_direnv = "shell_hook";

    inlay_hints.enabled = true;
    git.inline_blame.enabled = true;

    terminal = {
      font_family = "Maple Mono NF CN";
      font_fallbacks = [
        "JetBrainsMono Nerd Font"
        "Sarasa Term SC"
      ];
      font_size = 14;
    };

    languages = {
      Markdown = {
        formatter.external = {
          command = "prettier";
          arguments = [
            "--stdin-filepath"
            "{buffer_path}"
          ];
        };
      };

      Nix = {
        language_servers = [
          "nixd"
          "!nil"
          "..."
        ];
        formatter.external.command = "nixfmt";
      };

      Python = {
        language_servers = [
          "pyrefly"
          "ruff"
          "!basedpyright"
          "!pyright"
          "!pylsp"
          "..."
        ];
        formatter.language_server.name = "ruff";
      };

      Rust = {
        language_servers = [
          "rust-analyzer"
          "..."
        ];
        formatter = "language_server";
      };
    };

    lsp.pyrefly.initialization_options.python.pyrefly.displayTypeErrors = "force-on";
  };

  # ------------------------------------------------------------------------------------------------
  # Keymaps
  # ------------------------------------------------------------------------------------------------
  userKeymaps = [
    {
      context = "Workspace";
      bindings = {
        "ctrl-=" = "pane::GoForward";
      };
    }
  ];

  # ------------------------------------------------------------------------------------------------
  # Windows sync artifacts
  # ------------------------------------------------------------------------------------------------
  windowsSettings = lib.recursiveUpdate userSettings {
    auto_install_extensions = lib.genAttrs extensions (_: true);
    buffer_font_size = 15;
    terminal.font_size = 13;
  };

  windowsSettingsJson = json.generate "zed-windows-settings.json" windowsSettings;
  windowsKeymapsJson = json.generate "zed-windows-keymap.json" userKeymaps;
in
{
  inherit
    extensions
    userSettings
    userKeymaps
    windowsSettingsJson
    windowsKeymapsJson
    ;
}
