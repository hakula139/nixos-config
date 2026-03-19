{
  pkgs,
  isDarwin,
  isNixOS,
  flakePath,
  configName,
  ...
}:

# ==============================================================================
# Cursor Settings
# ==============================================================================

let
  json = pkgs.formats.json { };

  # ----------------------------------------------------------------------------
  # Base settings
  # ----------------------------------------------------------------------------
  settingsBase = builtins.fromJSON (builtins.readFile ./settings.json);

  # ----------------------------------------------------------------------------
  # nixd - machine-specific option completions
  # ----------------------------------------------------------------------------
  nixdCompletions =
    if flakePath != null then
      let
        configAttr =
          if isDarwin then
            "darwinConfigurations"
          else if isNixOS then
            "nixosConfigurations"
          else
            "homeConfigurations";

        flake = ''builtins.getFlake "${flakePath}"'';
        flakeConfig = "(${flake}).${configAttr}.${configName}";

        hmOptionsExpr =
          if isDarwin || isNixOS then
            "${flakeConfig}.options.home-manager.users.type.getSubOptions []"
          else
            "${flakeConfig}.options";
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
            { }
        );
      }
    else
      { };

  # ----------------------------------------------------------------------------
  # Override settings
  # ----------------------------------------------------------------------------
  settingsOverrides = {
    "bashIde.shellcheckPath" = "${pkgs.shellcheck}/bin/shellcheck";
    "bashIde.shfmt.path" = "${pkgs.shfmt}/bin/shfmt";
    "nix.serverPath" = "${pkgs.unstable.nixd}/bin/nixd";
    "nix.serverSettings" = {
      "nixd" = {
        formatting.command = [ "${pkgs.nixfmt}/bin/nixfmt" ];
      }
      // nixdCompletions;
    };
    # Use Nix-provided rust-analyzer instead of the extension's bundled binary.
    # On NixOS this bypasses the ELF patching bootstrap that fails in
    # air-gapped environments; on other platforms it simply pins the version.
    "rust-analyzer.server.path" = "${pkgs.unstable.rust-analyzer}/bin/rust-analyzer";
  };

  # ----------------------------------------------------------------------------
  # Final settings
  # ----------------------------------------------------------------------------
  settings = settingsBase // settingsOverrides;
in
{
  inherit settings;
  machineSettingsJson = json.generate "cursor-machine-settings.json" settingsOverrides;
  settingsJson = json.generate "cursor-settings.json" settings;
}
