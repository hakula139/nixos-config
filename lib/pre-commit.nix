# ==================================================================================================
# Pre-commit Hooks
# ==================================================================================================

{
  pkgs,
  inputs,
}:

(inputs.devkit.lib.mkLib pkgs).preCommit {
  src = inputs.self;

  hooks = {
    doctoc.enable = true;
    end-of-file-fixer.excludes = [ "\\.age$" ];
    nu-check.enable = true;
    prettier.enable = true;
    ruff.enable = true;
    ruff-format.enable = true;
    shellcheck.enable = true;
    shfmt.enable = true;
    taplo.enable = true;
    trim-trailing-whitespace.excludes = [
      "\\.age$"
      "\\.patch$"
    ];
  };
}
