# ==================================================================================================
# SSH Configuration
# ==================================================================================================

{
  lib,
}:

{
  # ------------------------------------------------------------------------------------------------
  # Distributed builders
  # ------------------------------------------------------------------------------------------------
  mkBuildMachines =
    servers: sshKey:
    map (server: {
      inherit sshKey;
      hostName = server.name;
      system = "x86_64-linux";
      protocol = "ssh-ng";
      sshUser = "root";
      maxJobs = server.maxJobs or 1;
      speedFactor = server.speedFactor or 1;
      supportedFeatures = [
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
    }) (lib.filter (s: s.isBuilder) servers);

  # ------------------------------------------------------------------------------------------------
  # SSH configuration helpers
  # ------------------------------------------------------------------------------------------------
  # The route to a server can pass through an Xray node, which closes a connection that carries no
  # traffic for a full 300 s check window. A remote build can be silent that long while it links,
  # so `ServerAliveInterval` keeps the connection active.
  mkExtraConfig =
    servers: sshKey:
    lib.concatMapStringsSep "\n" (server: ''
      Host ${server.name}
        HostName ${server.ip}
        Port ${toString server.port}
        User root
        IdentityFile ${sshKey}
        ServerAliveInterval 60
    '') servers;

  mkKnownHosts =
    servers:
    lib.listToAttrs (
      map (server: {
        inherit (server) name;
        value = {
          extraHostNames = [
            server.displayName
            server.ip
            "[${server.ip}]:${toString server.port}"
          ];
          publicKey = server.hostKey;
        };
      }) servers
    );
}
