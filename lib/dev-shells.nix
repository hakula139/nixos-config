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

  basePackages = preCommit.nativeBuildInputs ++ tooling.all;
in
{
  default = pkgs.mkShell {
    packages = tooling.all;

    inputsFrom = [ preCommit ];

    shellHook = ''
      export NU_LIB_DIRS="$(git rev-parse --show-toplevel)/lib/nu"
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
