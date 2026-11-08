# ==================================================================================================
# Pre-commit Checks
# ==================================================================================================

{
  pkgs,
  inputs,
}:

(inputs.devkit.lib.mkLib pkgs).preCommit {
  src = inputs.self;

  hooks = {
    actionlint.enable = true;
    check-yaml.enable = true;
    cspell.enable = true;
    deadnix.enable = true;
    doctoc.enable = true;
    dprint.enable = true;
    editorconfig-checker.enable = true;

    end-of-file-fixer.excludes = [ "\\.age$" ];

    markdownlint-cli2.enable = true;
    nixfmt.enable = true;
    nu-check.enable = true;
    prettier.enable = true;
    ruff.enable = true;
    ruff-format.enable = true;
    shellcheck.enable = true;
    shfmt.enable = true;
    sort-file-contents.enable = true;
    statix.enable = true;
    taplo.enable = true;

    trim-trailing-whitespace.excludes = [
      "\\.age$"
      "\\.patch$"
    ];
  };
}
