# ==================================================================================================
# Markdown Formatting
# ==================================================================================================

{
  pkgs,
}:

let
  json = pkgs.formats.json { };
in
json.generate "dprint.json" {
  markdown = {
    emphasisKind = "underscores";
    strongKind = "asterisks";
  };

  # Language plugins would also rewrite fenced examples inside Markdown.
  plugins = [ "${pkgs.dprint-plugins.dprint-plugin-markdown}/plugin.wasm" ];
}
