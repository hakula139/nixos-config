# ==================================================================================================
# Cursor Configuration
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  repoLib,
  systemManagerPaths,
  flakeConfigName,
  isDesktop,
  isNixOS,
  ...
}:

let
  inherit (pkgs.stdenv) isDarwin isLinux;

  cfg = config.hakula.cursor;
  agentsMcp = config.agents.resolved.mcp;
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
      enable = lib.mkEnableOption "syncing Cursor settings and keybindings to Windows (WSL only)";
    };

    mirroredNetworking = {
      enable = lib.mkEnableOption "turning off Cursor port forwarding in mirrored mode (WSL only)";
    };

    mcp = inputs.agents-nix.lib.mcp.mkMcpOptions {
      default = agentsMcp.serverNames;
      description = "MCP servers for Cursor";
    };
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
        inherit pkgs agentsMcp;
        enabledServers = agentsMcp.computeEnabledServers cfg.mcp;
      };

      settings = import ./settings {
        inherit
          config
          pkgs
          lib
          inputs
          flakeConfigName
          isDarwin
          isNixOS
          ;
      };

      extensions = import ./extensions.nix {
        inherit
          config
          pkgs
          lib
          repoLib
          isDarwin
          ;
      };

      remoteFiles = import ./remote.nix {
        inherit
          pkgs
          lib
          repoLib
          systemManagerPaths
          ;
        inherit (settings) machineSettingsJson;
        proxyCfg = config.agents.proxy;
      };

      windowsSync = import ./windows-sync.nix {
        inherit pkgs repoLib;
        inherit (settings) windowsSettingsJson;
      };

      # --------------------------------------------------------------------------------------------
      # Configuration files
      # --------------------------------------------------------------------------------------------
      configFiles = pkgs.runCommand "cursor-config" { } ''
        set -euo pipefail
        mkdir -p "$out"
        cp ${lib.escapeShellArg settings.settingsJson} "$out/settings.json"
        cp ${lib.escapeShellArg "${./keybindings.json}"} "$out/keybindings.json"
        ${lib.optionalString config.hakula.llm-assistants.enable ''
          cp ${lib.escapeShellArg mcp.mcpJson} "$out/mcp.json"
        ''}
      '';

      userFiles = dir: {
        "${dir}/settings.json".source = "${configFiles}/settings.json";
        "${dir}/keybindings.json".source = "${configFiles}/keybindings.json";
      };

      darwinFiles = userFiles "Library/Application Support/Cursor/User";
      linuxFiles = userFiles "Cursor/User";
    in
    {
      hakula.cursor.mcp.disabledServers = lib.mkDefault config.agents.mcp.disabledServers;

      # --------------------------------------------------------------------------------------------
      # User configuration files
      # --------------------------------------------------------------------------------------------
      home.packages = lib.optional cfg.windowsSync.enable windowsSync.syncWindowsSettings;

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
