# ==================================================================================================
# Cursor Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  flakeConfigName,
  repoLib,
  systemManagerPaths,
  isDesktop ? false,
  isNixOS ? false,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin isLinux;
  cfg = config.hakula.cursor;
  shared = config.lib.llmAssistants;

  inherit (repoLib.llmAssistants) mcpOptions;
  cursorMcpServers = mcpOptions.commonServerNames;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.cursor = {
    enable = lib.mkEnableOption "Cursor configuration";

    extensions = {
      enable = lib.mkEnableOption "installing the provisioned Cursor extensions";
      prune = lib.mkEnableOption "uninstalling Cursor extensions missing from the provisioned list";
    };

    windowsSync = {
      enable = lib.mkEnableOption "syncing Nix-managed Cursor settings to Windows (WSL only)";
    };

    mirroredNetworking = {
      enable = lib.mkEnableOption "turning off Cursor port forwarding in mirrored mode (WSL only)";
    };

    mcp = mcpOptions.mkMcpOptions { names = cursorMcpServers; };
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = lib.mkIf cfg.enable (
    let
      # --------------------------------------------------------------------------------------------
      # Module imports
      # --------------------------------------------------------------------------------------------
      mcp = import ./mcp.nix {
        inherit pkgs mcpOptions;
        enabledServers = mcpOptions.computeEnabledServers cfg.mcp;
        mcpServers = shared.mcp.servers;
      };

      settings = import ./settings {
        inherit
          pkgs
          lib
          flakeConfigName
          isDarwin
          isNixOS
          ;
        inherit (config.home) profileDirectory;
        flakePath = config.hakula.nix.configPath;
        mirroredNetworking = cfg.mirroredNetworking.enable;
        windowsInterop = repoLib.wsl.mkWindowsInterop pkgs;
      };

      extensions = import ./extensions.nix {
        inherit lib isDarwin;
        inherit (config.home) username;
        inherit (cfg.extensions) prune;
        homeDir = config.home.homeDirectory;
      };

      remoteFiles = import ./remote.nix {
        inherit pkgs lib systemManagerPaths;
        inherit (settings) machineSettingsJson;
      };

      # --------------------------------------------------------------------------------------------
      # Configuration files
      # --------------------------------------------------------------------------------------------
      configFiles = pkgs.runCommand "cursor-config" { } ''
        set -euo pipefail
        mkdir -p "$out"
        cp ${lib.escapeShellArg settings.settingsJson} "$out/settings.json"
        cp ${lib.escapeShellArg "${./keybindings.json}"} "$out/keybindings.json"
        cp ${lib.escapeShellArg mcp.mcpJson} "$out/mcp.json"
      '';

      darwinFiles = {
        "Library/Application Support/Cursor/User/settings.json".source = "${configFiles}/settings.json";
        "Library/Application Support/Cursor/User/keybindings.json".source =
          "${configFiles}/keybindings.json";
        "Library/Application Support/Cursor/User/snippets".source = ./snippets;
      };

      linuxFiles = {
        "Cursor/User/settings.json".source = "${configFiles}/settings.json";
        "Cursor/User/keybindings.json".source = "${configFiles}/keybindings.json";
        "Cursor/User/snippets".source = ./snippets;
      };
    in
    {
      # --------------------------------------------------------------------------------------------
      # User configuration files
      # --------------------------------------------------------------------------------------------
      home.packages = lib.optional cfg.windowsSync.enable settings.syncWindowsSettings;

      home.file =
        lib.optionalAttrs config.hakula.llm-assistants.enable {
          ".cursor/mcp.json".source = "${configFiles}/mcp.json";
        }
        // lib.optionalAttrs (isDesktop && isDarwin) darwinFiles
        // lib.optionalAttrs isLinux remoteFiles;

      xdg.configFile = lib.optionalAttrs (isDesktop && !isDarwin) linuxFiles;

      # --------------------------------------------------------------------------------------------
      # Extension management
      # --------------------------------------------------------------------------------------------
      home.activation.cursorExtensions = lib.mkIf cfg.extensions.enable extensions.activation;
    }
  );
}
