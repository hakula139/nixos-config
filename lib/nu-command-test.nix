# ==================================================================================================
# Nushell Command Guard Test
# ==================================================================================================

{
  pkgs,
  repoLib,
}:

let
  script = pkgs.writeText "nu-command-guard-test.nu" ''
    def main [path?: path, --flag: string] {
      print $flag
    }
  '';

  command = repoLib.mkNuCommand {
    inherit pkgs;
    name = "nu-command-guard-test";
    inherit script;
  };
in
pkgs.runCommand "nu-command-guard-test" { } ''
  marker="$TMPDIR/marker"
  injection="--help;^touch $marker"

  check-rejected() {
    set +e
    "$@" > /dev/null 2> "$TMPDIR/stderr"
    status=$?
    set -e
    if [ "$status" -ne 2 ]; then
      echo "expected exit 2, got $status: $*" >&2
      cat "$TMPDIR/stderr" >&2
      exit 1
    fi
  }

  check-rejected ${pkgs.lib.getExe command} "$injection"
  check-rejected ${pkgs.lib.getExe command} doc.md "$injection"
  check-rejected ${pkgs.lib.getExe command} "--model=x;^touch $marker"
  check-rejected ${pkgs.lib.getExe command} "--"

  if [ -e "$marker" ]; then
    echo "injected command ran" >&2
    exit 1
  fi

  ${pkgs.lib.getExe command} --flag value > /dev/null

  touch "$out"
''
