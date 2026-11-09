# ==================================================================================================
# Cursor Settings
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  inputs,
  repoLib,
  flakeConfigName,
  isDarwin,
  isNixOS,
}:

let
  cfg = config.hakula.cursor;
  flakePath = config.hakula.nix.configPath;
  json = pkgs.formats.json { };

  # ------------------------------------------------------------------------------------------------
  # Base settings
  # ------------------------------------------------------------------------------------------------
  settingsBase = lib.importJSON ./settings.json;
  windowsDisplaySettings = lib.importJSON ./windows-settings.json;

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

  # ------------------------------------------------------------------------------------------------
  # Portable settings
  # ------------------------------------------------------------------------------------------------
  portableSettings = {
    "bashIde.shellcheckPath" = "shellcheck";
    "bashIde.shfmt.path" = "shfmt";
    "nix.serverPath" = "nixd";
    "nix.serverSettings" = {
      nixd = {
        formatting.command = [ "nixfmt" ];
      };
    };
    "nushellLanguageServer.nushellExecutablePath" = "nu";
    "terminal.integrated.profiles.linux" = terminalProfiles;
    "terminal.integrated.profiles.osx" = terminalProfiles;
  };

  # ------------------------------------------------------------------------------------------------
  # Devkit settings
  # ------------------------------------------------------------------------------------------------
  # Kept out of the Windows output, where this store path does not exist.
  devkitSettings = {
    "markdownlint.configFile" = "${inputs.devkit}/.markdownlint-cli2.jsonc";
  };

  # ------------------------------------------------------------------------------------------------
  # nixd completions
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
  # Store path settings
  # ------------------------------------------------------------------------------------------------
  storePathSettings = {
    "bashIde.shellcheckPath" = lib.getExe pkgs.shellcheck;
    "bashIde.shfmt.path" = lib.getExe pkgs.shfmt;
    "direnv.path.executable" = lib.getExe pkgs.direnv;
    "nix.serverPath" = lib.getExe pkgs.nixd;
    "nix.serverSettings" = {
      nixd = {
        formatting.command = [ (lib.getExe pkgs.nixfmt) ];
      }
      // nixdCompletions;
    };
    "nushellLanguageServer.nushellExecutablePath" = lib.getExe pkgs.nushell;
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
  settingsJson = json.generate "cursor-settings.json" (
    settingsBase // portableSettings // devkitSettings
  );
  machineSettingsJson = json.generate "cursor-machine-settings.json" (
    portableSettings // storePathSettings // devkitSettings // mirroredNetworkingSettings
  );
  windowsSettingsJson = json.generate "cursor-windows-settings.json" (
    settingsBase // portableSettings // windowsDisplaySettings
  );

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
    settingsJson
    machineSettingsJson
    syncWindowsSettings
    ;
}
