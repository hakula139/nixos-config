#!/usr/bin/env nu

# ==================================================================================================
# Mihomo Port Check
# ==================================================================================================
# Windows can hold the mirrored loopback port, and mihomo then keeps running with only its
# controller. systemd must see the missing listener as a failure, since nothing else reports it.
# ==================================================================================================

# Within the unit's start timeout, wait for mihomo to replace the start script and bind the port.
def main [
  --port: int # Wrapper-supplied mixed port
  --pid: int # Main process PID, which the unit passes as $MAINPID
] {
  loop {
    let comm = (try { open $"/proc/($pid)/comm" | str trim } catch { "" })
    if $comm == "mihomo" {
      break
    }

    if $comm == "" {
      print --stderr $"Error: main process ($pid) exited before mihomo started"
      exit 1
    }

    sleep 500ms
  }

  mut waited = 0sec
  while $waited < 10sec {
    if (^ss -Htlpn $"sport = :($port)" | str contains $"pid=($pid),") {
      return
    }

    sleep 500ms
    $waited += 500ms
  }

  print --stderr $"Error: mihomo pid ($pid) has no listener on mixed port ($port)"
  exit 1
}
