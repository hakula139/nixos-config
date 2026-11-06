# ==================================================================================================
# Dev Shells
# ==================================================================================================

{
  pkgs,
  preCommitCheck,
}:

let
  inherit (pkgs) lib;

  tooling = import ./tooling.nix { inherit pkgs; };

  # mkShell adds packages to PATH in list order, and the hook packages propagate a bare `python3`,
  # so each shell lists its own packages ahead of these.
  basePackages = preCommitCheck.enabledPackages ++ tooling.all;

  flock = lib.getExe pkgs.flock;
  git = lib.getExe pkgs.git;
in
{
  default = pkgs.mkShell {
    packages = [
      preCommitCheck.config.package
      tooling.scriptPython
    ]
    ++ basePackages;

    # git-hooks.nix stores a main-checkout-relative path that linked worktrees cannot resolve
    # (cachix/git-hooks.nix#688). Serialize installation before clearing it.
    shellHook = ''
      if common=$(
        ${git} rev-parse \
          --path-format=absolute \
          --git-common-dir \
          2>/dev/null
      ); then
        (
          ${flock} 9
          ${preCommitCheck.config.installationScript}
          ${git} config --local --unset-all core.hooksPath || true
        ) 9>"$common/git-hooks.lock"
      fi
    '';
  };

  browser = pkgs.mkShell {
    packages = [
      pkgs.browser-tools
      pkgs.nodejs_26
      (pkgs.unstable.python3.withPackages (ps: [
        ps.playwright
      ]))
    ]
    ++ basePackages;

    PLAYWRIGHT_BROWSERS_PATH = pkgs.browser-tools.browsers;
  };
}
