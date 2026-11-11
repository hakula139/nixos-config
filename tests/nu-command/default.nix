# ==================================================================================================
# Nushell Command Check
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
      count = 3;
    };
  };

  plain = command { };
in
pkgs.runCommand "nu-command-check" { nativeBuildInputs = [ pkgs.nushell ]; } ''
  nu --no-config-file ${./test.nu} ${pkgs.lib.getExe configured} ${pkgs.lib.getExe plain}
  touch "$out"
''
