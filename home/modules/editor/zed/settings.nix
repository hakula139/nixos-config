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
    # ----------------------------------------------------------------------------------------------
    # Appearance
    # ----------------------------------------------------------------------------------------------
    buffer_font_fallbacks = [ "Sarasa Mono SC" ];
    buffer_font_family = "Maple Mono NF CN";
    buffer_font_size = 16;

    icon_theme = {
      dark = "Catppuccin Mocha";
      light = "Catppuccin Latte";
      mode = "system";
    };
    theme = {
      dark = "Catppuccin Mocha";
      light = "Catppuccin Latte";
      mode = "system";
    };

    # ----------------------------------------------------------------------------------------------
    # Editor
    # ----------------------------------------------------------------------------------------------
    autosave = "off";
    base_keymap = "VSCode";
    ensure_final_newline_on_save = false;
    format_on_save = "on";
    git.inline_blame.enabled = true;
    inlay_hints.enabled = true;
    load_direnv = "shell_hook";
    session.trust_all_worktrees = true;
    tab_size = 2;

    telemetry = {
      diagnostics = false;
      metrics = false;
    };

    # ----------------------------------------------------------------------------------------------
    # Terminal
    # ----------------------------------------------------------------------------------------------
    terminal = {
      font_fallbacks = [
        "JetBrainsMono Nerd Font"
        "Sarasa Term SC"
      ];
      font_family = "Maple Mono NF CN";
      font_size = 14;
    };

    # ----------------------------------------------------------------------------------------------
    # Languages & LSP
    # ----------------------------------------------------------------------------------------------
    languages = {
      Markdown = {
        formatter.external = {
          arguments = [
            "--stdin-filepath"
            "{buffer_path}"
          ];
          command = "prettier";
        };
      };

      Nix = {
        formatter.external.command = "nixfmt";
        language_servers = [
          "nixd"
          "!nil"
          "..."
        ];
      };

      Python = {
        formatter.language_server.name = "ruff";
        language_servers = [
          "pyrefly"
          "ruff"
          "!basedpyright"
          "!pyright"
          "!pylsp"
          "..."
        ];
      };

      Rust = {
        formatter = "language_server";
        language_servers = [
          "rust-analyzer"
          "..."
        ];
      };
    };

    lsp.pyrefly.initialization_options.python.pyrefly.typeCheckingMode = "default";

    # ----------------------------------------------------------------------------------------------
    # Agent servers
    # ----------------------------------------------------------------------------------------------
    agent_servers = {
      "Claude Code" = {
        args = [ ];
        command = "claude-agent-acp";
        env = { };
        type = "custom";
      };

      Codex = {
        args = [ ];
        command = "codex-acp";
        env = { };
        type = "custom";
      };
    };
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
