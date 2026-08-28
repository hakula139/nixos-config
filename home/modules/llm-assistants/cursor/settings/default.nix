# ==============================================================================
# Cursor Settings
# ==============================================================================

{
  pkgs,
  flakeConfigName,
  flakePath,
  isDarwin,
  isNixOS,
  profileDirectory,
  ...
}:

let
  json = pkgs.formats.json { };

  # ----------------------------------------------------------------------------
  # Base settings
  # ----------------------------------------------------------------------------
  settingsBase = builtins.fromJSON (builtins.readFile ./settings.json);
  windowsSettings = builtins.fromJSON (builtins.readFile ./windows-settings.json);

  # ----------------------------------------------------------------------------
  # Terminal profiles
  # ----------------------------------------------------------------------------
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

  # ----------------------------------------------------------------------------
  # nixd — machine-specific option completions
  # ----------------------------------------------------------------------------
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

  # ----------------------------------------------------------------------------
  # Portable settings
  # ----------------------------------------------------------------------------
  portableSettings = {
    "bashIde.shellcheckPath" = "shellcheck";
    "bashIde.shfmt.path" = "shfmt";
    "nix.serverPath" = "nixd";
    "nix.serverSettings" = {
      "nixd" = {
        formatting.command = [ "nixfmt" ];
      };
    };
    "nushellLanguageServer.nushellExecutablePath" = "nu";
  }
  // terminalSettings;

  # ----------------------------------------------------------------------------
  # Machine settings
  # ----------------------------------------------------------------------------
  machineSettings = portableSettings // {
    "bashIde.shellcheckPath" = "${pkgs.shellcheck}/bin/shellcheck";
    "bashIde.shfmt.path" = "${pkgs.shfmt}/bin/shfmt";
    "direnv.path.executable" = "${pkgs.direnv}/bin/direnv";
    "nix.serverPath" = "${pkgs.nixd}/bin/nixd";
    "nix.serverSettings" = {
      "nixd" = {
        formatting.command = [ "${pkgs.nixfmt}/bin/nixfmt" ];
      }
      // nixdCompletions;
    };
    "nushellLanguageServer.nushellExecutablePath" = "${pkgs.nushell}/bin/nu";
    "python.defaultInterpreterPath" = "${profileDirectory}/bin/python";
  };

  # ----------------------------------------------------------------------------
  # Final settings
  # ----------------------------------------------------------------------------
  settings = settingsBase // portableSettings;
in
{
  inherit settings;
  machineSettingsJson = json.generate "cursor-machine-settings.json" machineSettings;
  settingsJson = json.generate "cursor-settings.json" settings;
  windowsSettingsJson = json.generate "cursor-windows-settings.json" (settings // windowsSettings);
}
