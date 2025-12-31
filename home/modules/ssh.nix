{ config, ... }:

let
  homeDir = config.home.homeDirectory;
in
{
  # ============================================================================
  # SSH Configuration
  # ============================================================================
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "*" = { };
      "CloudCone-US-1" = {
        host = "CloudCone-US-1";
        hostname = "74.48.108.20";
        user = "hakula";
        port = 35060;
        identityFile = "${homeDir}/.ssh/CloudCone/id_ed25519";
        forwardAgent = true;
      };
      "CloudCone-US-2" = {
        host = "CloudCone-US-2";
        hostname = "74.48.189.161";
        user = "hakula";
        port = 35060;
        identityFile = "${homeDir}/.ssh/CloudCone/id_ed25519";
        forwardAgent = true;
      };
      "Tencent-SG-1" = {
        host = "Tencent-SG-1";
        hostname = "43.134.225.50";
        user = "hakula";
        port = 35060;
        identityFile = "${homeDir}/.ssh/Tencent/id_ed25519";
        forwardAgent = true;
      };
    };
  };
}
