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
    markdownlint-cli2.settings.configPath = "";
    nu-check = {
      enable = true;
      settings.libDirs = [
        repoLib.nuTestLib
        repoLib.devkitNuLibDir
      ];
    };
    prettier = {
      enable = true;
      excludes = [ "^secrets/" ];
    };
    shellcheck.enable = true;
    shfmt.enable = true;
    taplo.enable = true;
    trim-trailing-whitespace.excludes = [
      "^secrets/"
      "\\.patch$"
    ];
  };
}
