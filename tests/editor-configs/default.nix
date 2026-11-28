# ==================================================================================================
# Devkit Editor Configuration Check
# ==================================================================================================

{
  pkgs,
  devkit,
}:

pkgs.runCommand "devkit-editor-configs" { } ''
  diff -u ${devkit}/.markdownlint.jsonc ${../../.markdownlint/devkit.jsonc}
  diff -u ${devkit}/.prettierrc.json ${../../.prettierrc.json}
  diff -u ${devkit}/.taplo.toml ${../../.taplo.toml}

  cat ${devkit}/.editorconfig > expected
  printf '\n%s\n%s\n' '[*.patch]' 'trim_trailing_whitespace = false' >> expected
  diff -u expected ${../../.editorconfig}
  touch "$out"
''
