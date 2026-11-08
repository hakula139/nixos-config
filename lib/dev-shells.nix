# ==================================================================================================
# Dev Shells
# ==================================================================================================

{
  pkgs,
  preCommit,
}:

let
  tooling = import ./tooling.nix {
    inherit pkgs;
  };

  # mkShell adds packages to PATH in list order, and the hook packages propagate a bare `python3`,
  # so each shell lists its own packages ahead of these.
  basePackages = preCommit.packages ++ tooling.all;
in
{
  default = pkgs.mkShell {
    packages = [
      tooling.scriptPython
    ]
    ++ tooling.all;

    inputsFrom = [ preCommit ];
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
