{ pkgs, ... }:

# ==============================================================================
# Cursor Settings
# ==============================================================================

let
  settingsBase = builtins.fromJSON (builtins.readFile ./settings.json);

  settingsOverrides = {
    "bashIde.shellcheckPath" = "${pkgs.shellcheck}/bin/shellcheck";
    "bashIde.shfmt.path" = "${pkgs.shfmt}/bin/shfmt";
  };

  settings = settingsBase // settingsOverrides;
  settingsJson = (pkgs.formats.json { }).generate "cursor-settings.json" settings;
in
{
  inherit settings settingsJson;
}
