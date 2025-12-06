{ config, pkgs }:

let
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.jinja2 ]);
  generator = pkgs.copyPathToStore ./generator.py;
  template = pkgs.copyPathToStore ./template.yaml.j2;
in
pkgs.writeShellScript "clash-generator" ''
  set -euo pipefail
  ${pythonEnv}/bin/python3 ${generator} \
    "${config.age.secrets.clash-users.path}" \
    "${template}" \
    "/var/lib/clash-subscriptions"
''
