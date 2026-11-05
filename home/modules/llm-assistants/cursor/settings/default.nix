# ==================================================================================================
# Cursor Settings
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  flakeConfigName,
  isDarwin,
  isNixOS,
  repoLib,
}:

let
  cfg = config.hakula.cursor;
  flakePath = config.hakula.nix.configPath;
  json = pkgs.formats.json { };

  # ------------------------------------------------------------------------------------------------
  # Base settings
  # ------------------------------------------------------------------------------------------------
  settingsBase = lib.importJSON ./settings.json;
  windowsSettings = lib.importJSON ./windows-settings.json;

  # ------------------------------------------------------------------------------------------------
  # Terminal profiles
  # ------------------------------------------------------------------------------------------------
  terminalProfiles = {
    bash = {
      args = [ "-l" ];
      icon = "terminal-bash";
      path = "bash";
    };

    tmux = {
      args = [
        "-lc"
        ''exec tmux new-session -A -s "''${PWD##*/}"''
      ];

      icon = "terminal-tmux";
      path = "bash";
    };

    zsh = {
      args = [
        "-l"
        "-i"
      ];

      path = "zsh";
    };
  };

  terminalSettings = {
    "terminal.integrated.profiles.linux" = terminalProfiles;
    "terminal.integrated.profiles.osx" = terminalProfiles;
  };

  # ------------------------------------------------------------------------------------------------
  # nixd - machine-specific option completions
  # ------------------------------------------------------------------------------------------------
  nixdCompletions =
    if flakePath != null && flakeConfigName != null then
      let
        configAttr =
          if isDarwin then
            "darwinConfigurations"
          else if isNixOS then
            "nixosConfigurations"
          else
            "systemConfigs";

        flake = ''builtins.getFlake "${flakePath}"'';
        flakeConfig = "(${flake}).${configAttr}.${builtins.toJSON flakeConfigName}";

        hmOptionsExpr = "${flakeConfig}.options.home-manager.users.type.getSubOptions []";
      in
      {
        nixpkgs.expr = "import (${flake}).inputs.nixpkgs { }";

        options = {
          home-manager.expr = hmOptionsExpr;
        }
        // (
          if isDarwin then
            { darwin.expr = "${flakeConfig}.options"; }
          else if isNixOS then
            { nixos.expr = "${flakeConfig}.options"; }
          else
            { system-manager.expr = "${flakeConfig}.options"; }
        );
      }
    else
      { };

  # ------------------------------------------------------------------------------------------------
  # Portable settings
  # ------------------------------------------------------------------------------------------------
  portableSettings = terminalSettings // {
    "bashIde.shellcheckPath" = "shellcheck";
    "bashIde.shfmt.path" = "shfmt";

    "nix.serverPath" = "nixd";
    "nix.serverSettings" = {
      nixd = {
        formatting.command = [ "nixfmt" ];
      };
    };

    "nushellLanguageServer.nushellExecutablePath" = "nu";
  };

  # ------------------------------------------------------------------------------------------------
  # Machine settings
  # ------------------------------------------------------------------------------------------------
  machineSettings = portableSettings // {
    "bashIde.shellcheckPath" = lib.getExe pkgs.shellcheck;
    "bashIde.shfmt.path" = lib.getExe pkgs.shfmt;

    "nix.serverPath" = lib.getExe pkgs.nixd;
    "nix.serverSettings" = {
      nixd = {
        formatting.command = [ (lib.getExe pkgs.nixfmt) ];
      }
      // nixdCompletions;
    };

    "nushellLanguageServer.nushellExecutablePath" = lib.getExe pkgs.nushell;

    "direnv.path.executable" = lib.getExe pkgs.direnv;

    "python.defaultInterpreterPath" = "${config.home.profileDirectory}/bin/python";
  };

  # ------------------------------------------------------------------------------------------------
  # Mirrored networking settings
  # ------------------------------------------------------------------------------------------------
  # Mirrored networking already exposes WSL listeners on Windows localhost, so a forward is
  # redundant, and one that binds while the WSL server is down holds the port it needs.
  mirroredNetworkingSettings = lib.optionalAttrs cfg.mirroredNetworking.enable {
    "remote.autoForwardPorts" = false;
    "remote.forwardOnOpen" = false;
    "remote.restoreForwardedPorts" = false;
  };

  # ------------------------------------------------------------------------------------------------
  # Final settings
  # ------------------------------------------------------------------------------------------------
  settings = settingsBase // portableSettings;

  settingsJson = json.generate "cursor-settings.json" settings;
  machineSettingsJson = json.generate "cursor-machine-settings.json" (
    machineSettings // mirroredNetworkingSettings
  );
  windowsSettingsJson = json.generate "cursor-windows-settings.json" (settings // windowsSettings);

  # ------------------------------------------------------------------------------------------------
  # Windows sync
  # ------------------------------------------------------------------------------------------------
  syncWindowsSettings = repoLib.mkNuCommand {
    inherit pkgs;
    name = "sync-windows-cursor-settings";
    script = ./sync-windows-settings.nu;

    config = {
      settingsFile = windowsSettingsJson;
      windowsInterop = repoLib.wsl.mkWindowsInterop pkgs;
    };
  };
in
{
  inherit
    settings
    settingsJson
    machineSettingsJson
    windowsSettingsJson
    syncWindowsSettings
    ;
}
