# ==================================================================================================
# Aria2 Settings
# ==================================================================================================

{
  downloadSettings = {
    continue = true;
    max-connection-per-server = 4;
    split = 4;
  };

  rpcSettings = {
    rpc-listen-all = false;
    rpc-listen-port = 6800;
  };
}
