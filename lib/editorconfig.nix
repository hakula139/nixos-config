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
in

{
  # Null when the glob or the key is absent, so a caller cannot mistake a
  # missing rule for a default.
  indentSizeOf =
    text: glob:
    let
      matched = builtins.match ".*indent_size *= *([0-9]+).*" (sectionOf text glob);
    in
    if matched == null then null else lib.toInt (lib.head matched);
}
