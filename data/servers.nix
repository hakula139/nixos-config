# ==================================================================================================
# Server Inventory
# ==================================================================================================

let
  keys = import ../secrets/keys.nix;
in
{
  us-1 = {
    ip = "148.135.55.79";
    port = 35060;
    name = "us-1";
    displayName = "CloudCone-US-1";
    provider = "CloudCone";
    hostKey = keys.hosts.us-1;
    proxyLevel = "user";
    isBuilder = false;
  };

  us-4 = {
    ip = "64.186.235.130";
    port = 35060;
    name = "us-4";
    displayName = "DMIT-US-4";
    provider = "DMIT";
    hostKey = keys.hosts.us-4;
    proxyLevel = "admin";
    isBuilder = true;
    maxJobs = 3;
    speedFactor = 6;
  };
}
