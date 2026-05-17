# ==============================================================================
# Server Inventory
# ==============================================================================

let
  keys = import ../secrets/keys.nix;
in
{
  us-1 = {
    ip = "74.48.108.20";
    port = 35060;
    name = "us-1";
    displayName = "CloudCone-US-1";
    provider = "CloudCone";
    hostKey = keys.hosts.us-1;
    isBuilder = false;
  };

  us-2 = {
    ip = "74.48.189.161";
    port = 35060;
    name = "us-2";
    displayName = "CloudCone-US-2";
    provider = "CloudCone";
    hostKey = keys.hosts.us-2;
    isBuilder = false;
  };

  us-3 = {
    ip = "148.135.122.201";
    port = 35060;
    name = "us-3";
    displayName = "CloudCone-US-3";
    provider = "CloudCone";
    hostKey = keys.hosts.us-3;
    isBuilder = false;
  };

  us-4 = {
    ip = "64.186.235.130";
    port = 35060;
    name = "us-4";
    displayName = "DMIT-US-4";
    provider = "DMIT";
    hostKey = keys.hosts.us-4;
    isBuilder = true;
    maxJobs = 3;
    speedFactor = 6;
  };

  sg-1 = {
    ip = "43.134.225.50";
    port = 35060;
    name = "sg-1";
    displayName = "Tencent-SG-1";
    provider = "Tencent";
    hostKey = keys.hosts.sg-1;
    isBuilder = false;
  };
}
