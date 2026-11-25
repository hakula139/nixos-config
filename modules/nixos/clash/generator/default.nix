# ==================================================================================================
# Clash Subscription Generator
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  repoLib,
  servers,
  telemetryDomains,
}:

let
  json = pkgs.formats.json { };

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.jinja2
  ]);
  generator = pkgs.copyPathToStore ./generator.py;
  template = pkgs.copyPathToStore ./template.yaml.j2;
  serversFile = json.generate "clash-servers.json" (
    map (server: {
      id = server.name;
      inherit (server) ip;
      level = server.proxyLevel;
    }) (lib.attrValues servers)
  );
  telemetryDomainsFile = json.generate "clash-telemetry-domains.json" (
    repoLib.telemetry.clashDomains telemetryDomains
  );
in
pkgs.writeShellScript "clash-generator" ''
  set -euo pipefail

  outputDir="''${STATE_DIRECTORY:-/var/lib/clash-generator}"

  ${lib.getExe' pythonEnv "python3"} ${generator} \
    --users-path "${config.age.secrets.clash-users.path}" \
    --servers-path "${serversFile}" \
    --telemetry-domains-path "${telemetryDomainsFile}" \
    --template-path "${template}" \
    --sni-host "${config.hakula.network.realitySniHost}" \
    --output-dir "$outputDir"
''
