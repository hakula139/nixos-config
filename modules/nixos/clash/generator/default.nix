{
  config,
  pkgs,
  realitySniHost,
}:

# ==============================================================================
# Clash Subscription Generator
# ==============================================================================

let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.jinja2 ]);
  generator = pkgs.copyPathToStore ./generator.py;
  template = pkgs.copyPathToStore ./template.yaml.j2;
in
pkgs.writeShellScript "clash-generator" ''
  set -euo pipefail
  ${pythonEnv}/bin/python3 ${generator} \
    -u "${config.age.secrets.clash-users.path}" \
    -t "${template}" \
    -s "${realitySniHost}" \
    -o "/var/lib/clash-subscriptions"
''
