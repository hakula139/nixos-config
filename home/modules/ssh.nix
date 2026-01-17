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
      "github.com-hakula139" = {
        host = "github.com-hakula139";
        hostname = "github.com";
        user = "git";
        identityFile = "${homeDir}/.ssh/GitHub/hakula139";
      };
      "github.com-hc492874" = {
        host = "github.com-hc492874";
        hostname = "github.com";
        user = "git";
        identityFile = "${homeDir}/.ssh/GitHub/hc492874";
      };
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
      "CloudCone-US-3" = {
        host = "CloudCone-US-3";
        hostname = "148.135.122.201";
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
      "Hakula-MacBook" = {
        host = "Hakula-MacBook";
        hostname = "hakula-macbook";
        user = "hakula";
        port = 22;
        identityFile = "${homeDir}/.ssh/id_ed25519";
        forwardAgent = true;
      };
    };
  };
}
