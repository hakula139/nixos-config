# ==================================================================================================
# Nushell Command Integration Test
# ==================================================================================================

{
  pkgs,
  repoLib,
}:

let
  command =
    extra:
    repoLib.mkNuCommand (
      {
        inherit pkgs;
        name = "nu-command-fixture";
        script = ./echo-arguments.nu;
      }
      // extra
    );

  configured = command {
    config = {
      name = "adapter";
      nested.value = 2;
    };

    flags = {
      mode = "fast";
      count = "3";
    };

    makeWrapperArgs = [
      "--set"
      "NU_COMMAND_TEST_ENV"
      "wrapper"

      "--add-flag"
      "--count"

      "--add-flag"
      "5"
    ];
  };

  plain = command { };
in
pkgs.runCommand "nu-command-integration-test" { nativeBuildInputs = [ pkgs.jq ]; } ''
  bash ${./integration-test.sh} ${pkgs.lib.getExe configured} ${pkgs.lib.getExe plain}
  touch "$out"
''
