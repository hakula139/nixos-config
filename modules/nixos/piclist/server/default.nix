{
  pkgs,
  nodejs,
  configPath,
  tokenPath,
  ...
}:

# ==============================================================================
# PicList Server
# ==============================================================================

let
  version = "2.0.4";

  picgoServerBin = "node_modules/.bin/picgo-server";
  piclistPkgJson = "node_modules/piclist/package.json";

  runScript = pkgs.writeText "piclist-run.sh" ''
    set -euo pipefail

    cd "$STATE_DIRECTORY"

    installedVersion="$(node -p "require('./${piclistPkgJson}').version" 2>/dev/null || true)"

    if [ ! -x "${picgoServerBin}" ] || [ "$installedVersion" != "${version}" ]; then
      echo "Installing piclist@${version}..."
      rm -rf node_modules package.json package-lock.json
      npm init -y
      npm install piclist@${version}
    fi

    install -m 0600 "${configPath}" config.json

    SECRET_KEY=$(cat "${tokenPath}")
    exec "./${picgoServerBin}" -c config.json -k "$SECRET_KEY"
  '';
in
pkgs.writeShellApplication {
  name = "piclist-server";
  runtimeInputs = with pkgs; [
    bash
    coreutils
    findutils
    gnugrep
    gnused
    nodejs
  ];
  text = ''
    exec ${pkgs.bash}/bin/bash ${runScript}
  '';
}
