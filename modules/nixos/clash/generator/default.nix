# ==============================================================================
# Clash Subscription Generator
# ==============================================================================

{
  config,
  pkgs,
  lib,
  realitySniHost,
}:

let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.jinja2 ]);
  generator = pkgs.copyPathToStore ./generator.py;
  template = pkgs.copyPathToStore ./template.yaml.j2;
in
pkgs.writeShellScript "clash-generator" ''
  set -euo pipefail

  outputDir="''${STATE_DIRECTORY:-/var/lib/clash-generator}"

  ${lib.getExe' pythonEnv "python3"} ${generator} \
    -u "${config.age.secrets.clash-users.path}" \
    -t "${template}" \
    -s "${realitySniHost}" \
    -o "$outputDir"
''
