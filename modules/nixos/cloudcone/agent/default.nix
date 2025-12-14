{
  config,
  pkgs,
  ...
}:

# ==============================================================================
# CloudCone Agent Builder
# ==============================================================================

let
  agentScript = pkgs.copyPathToStore ./agent.sh;
in
pkgs.writeShellApplication {
  name = "cloudcone-agent";
  runtimeInputs = with pkgs; [
    coreutils
    curl
    findutils
    gawk
    gnugrep
    inetutils
    iproute2
    iputils
    procps
    util-linux
  ];
  text = ''
    export CLOUDCONE_SERVER_KEY_FILE="${config.services.cloudconeAgent.serverKeyFile}"
    exec ${pkgs.bash}/bin/bash ${agentScript}
  '';
}
