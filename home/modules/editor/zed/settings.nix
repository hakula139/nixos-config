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
    # Theme & Icons
    "catppuccin"
    "catppuccin-icons"

    # Languages & Data Formats
    "basher"
    "csv"
    "haskell"
    "html"
    "html-jinja"
    "jinja2"
    "latex"
    "mermaid"
    "neocmake"
    "nix"
    "nu"
    "proto"
    "rainbow-csv"
    "sql"
    "toml"
    "typst"
    "vue"
    "xml"

    # Linters & Spell Checker
    "cspell"
    "markdownlint"

    # Containers, Kubernetes & CI
    "docker-compose"
    "dockerfile"
    "github-actions"
    "gitlab-ci-ls"
    "helm"

    # Utilities
    "wakatime"
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

    theme_overrides."Catppuccin Mocha"."terminal.background" = "#0F111A";

    tabs = {
      file_icons = true;
      git_status = true;
    };

    ui_font_fallbacks = [
      "Sarasa UI SC"
      "PingFang SC"
      "Microsoft YaHei UI"
    ];
    ui_font_family = ".SystemUIFont";

    # ----------------------------------------------------------------------------------------------
    # Panels
    # ----------------------------------------------------------------------------------------------
    agent.dock = "right";
    collaboration_panel.button = false;
    git_panel.dock = "left";
    notification_panel.button = false;
    outline_panel.dock = "left";
    project_panel.dock = "left";

    # ----------------------------------------------------------------------------------------------
    # Editor
    # ----------------------------------------------------------------------------------------------
    autosave = "off";
    base_keymap = "VSCode";
    diagnostics.inline.enabled = true;
    ensure_final_newline_on_save = false;
    format_on_save = "on";
    git.inline_blame.enabled = true;
    inlay_hints.enabled = true;
    load_direnv = "shell_hook";
    preferred_line_length = 100;
    session.trust_all_worktrees = true;
    show_wrap_guides = true;
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
      option_as_meta = true;

      shell.with_arguments = {
        args = [
          "-lc"
          ''
            if command -v tmux >/dev/null 2>&1 && [ -z "''${TMUX:-}" ]; then
              session_name=$(printf '%s' "''${PWD##*/}" | LC_ALL=C tr -c '[:alnum:]' '[-*]')
              exec tmux new-session -A -s "$session_name"
            else
              exec "''${SHELL:-/bin/sh}" -l
            fi
          ''
        ];
        program = "sh";
      };
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
  terminalPassthroughKeys = map (key: "ctrl-${key}") (
    lib.stringToCharacters "abcdefghijklmnopqrstuvwxyz"
  );

  userKeymaps = [
    {
      context = "Terminal";
      bindings = lib.genAttrs terminalPassthroughKeys (key: [
        "terminal::SendKeystroke"
        key
      ]);
    }

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
    agent_buffer_font_size = 16;
    auto_install_extensions = lib.genAttrs extensions (_: true);
    buffer_font_size = 18;
    terminal = {
      # Clear multiline nix-direnv hooks that break Zed's `wsl.exe --` terminal launch.
      env = {
        buildPhase = "";
        shellHook = "";
      };
      font_size = 16;
    };
    ui_font_size = 19;
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
