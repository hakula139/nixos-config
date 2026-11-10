# ==================================================================================================
# Nushell Command Guard Test
# ==================================================================================================

{
  pkgs,
  repoLib,
}:

let
  command = repoLib.mkNuCommand {
    inherit pkgs;
    name = "nu-command-guard-test";
    script = ./nu-command-test.nu;
  };

  executable = pkgs.lib.getExe command;
in
pkgs.runCommand "nu-command-guard-test" { } ''
  bash ${./nu-command-test.sh} ${executable}
  touch "$out"
''
