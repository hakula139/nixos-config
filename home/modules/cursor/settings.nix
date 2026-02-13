{
  pkgs,
  isDarwin,
  isNixOS,
  configName,
  homeDir,
  ...
}:

# ==============================================================================
# Cursor Settings
# ==============================================================================

let
  settingsBase = builtins.fromJSON (builtins.readFile ./settings.json);

  # ----------------------------------------------------------------------------
  # nixd — machine-specific option completions
  # ----------------------------------------------------------------------------
  flakePath = "${homeDir}/GitHub/nixos-config";
  flake = ''builtins.getFlake "${flakePath}"'';

  configAttr =
    if isDarwin then
      "darwinConfigurations"
    else if isNixOS then
      "nixosConfigurations"
    else
      "homeConfigurations";

  flakeConfig = "(${flake}).${configAttr}.${configName}";

  hmOptionsExpr =
    if isDarwin || isNixOS then
      "${flakeConfig}.options.home-manager.users.type.getSubOptions []"
    else
      "${flakeConfig}.options";

  nixdSettings = {
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
        { }
    );
  };

  # ----------------------------------------------------------------------------
  # Settings overrides
  # ----------------------------------------------------------------------------
  settingsOverrides = {
    "bashIde.shellcheckPath" = "${pkgs.shellcheck}/bin/shellcheck";
    "bashIde.shfmt.path" = "${pkgs.shfmt}/bin/shfmt";
    "nix.serverPath" = "${pkgs.unstable.nixd}/bin/nixd";
    "nix.serverSettings" = {
      "nixd" = {
        formatting.command = [ "${pkgs.nixfmt}/bin/nixfmt" ];
      }
      // nixdSettings;
    };
  };

  # ----------------------------------------------------------------------------
  # Final settings
  # ----------------------------------------------------------------------------
  settings = settingsBase // settingsOverrides;
  settingsJson = (pkgs.formats.json { }).generate "cursor-settings.json" settings;
in
{
  inherit settings settingsJson;
}
