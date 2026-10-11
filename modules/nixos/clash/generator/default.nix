# ==================================================================================================
# Clash Subscription Generator
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  servers,
  realitySniHost,
}:

let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.jinja2 ]);
  generator = pkgs.copyPathToStore ./generator.py;
  template = pkgs.copyPathToStore ./template.yaml.j2;
  serversFile = (pkgs.formats.json { }).generate "clash-servers.json" (
    map (server: {
      id = server.name;
      level = server.proxyLevel;
    }) (lib.attrValues servers)
  );
in
pkgs.writeShellScript "clash-generator" ''
  set -euo pipefail

  outputDir="''${STATE_DIRECTORY:-/var/lib/clash-generator}"

  ${lib.getExe' pythonEnv "python3"} ${generator} \
    -u "${config.age.secrets.clash-users.path}" \
    -S "${serversFile}" \
    -t "${template}" \
    -s "${realitySniHost}" \
    -o "$outputDir"
''
