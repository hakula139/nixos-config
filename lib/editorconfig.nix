# ==============================================================================
# EditorConfig Reader
# ==============================================================================
# Lets a tool that cannot read `.editorconfig` derive its layout rules from the
# same source. `builtins.fromTOML` rejects the format, since `[*.nu]` is not a
# valid TOML key.
# ==============================================================================

{ lib }:

let
  sectionOf =
    text: glob:
    let
      afterHeader = lib.lists.drop 1 (lib.strings.splitString "[${glob}]" text);
    in
    if afterHeader == [ ] then "" else lib.head (lib.strings.splitString "\n[" (lib.head afterHeader));

  # A tool that silently formatted against its own default would contradict
  # whatever `.editorconfig` says, so an absent setting is a build failure.
  require =
    parse: text: glob: key:
    let
      matched = builtins.match ".*${key} *= *([^ \n]+).*" (sectionOf text glob);
    in
    if matched == null then
      throw "no ${key} for [${glob}] in .editorconfig"
    else
      parse (lib.head matched);
in

{
  readerFor =
    file:
    let
      text = builtins.readFile file;
    in
    {
      intOf = require lib.toInt text;
      boolOf = require (v: v == "true") text;
    };
}
