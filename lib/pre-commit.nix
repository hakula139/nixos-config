# ==================================================================================================
# Pre-commit Hooks
# ==================================================================================================

{
  pkgs,
  inputs,
  repoLib,
}:

(inputs.devkit.lib.mkLib pkgs).preCommit {
  src = inputs.self;

  hooks = {
    doctoc.enable = true;
    end-of-file-fixer.excludes = [ "^secrets/" ];
    nu-check = {
      enable = true;
      settings.libDirs = [ repoLib.nuTestLib ];
    };
    prettier = {
      enable = true;
      excludes = [ "^secrets/" ];
    };
    ruff.enable = true;
    ruff-format.enable = true;
    shellcheck.enable = true;
    shfmt.enable = true;
    taplo.enable = true;
    trim-trailing-whitespace.excludes = [
      "^secrets/"
      "\\.patch$"
    ];
  };
}
