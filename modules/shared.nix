{
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# Shared Configuration (cross-platform)
# ==============================================================================

let
  keys = import ../secrets/keys.nix;
  binaryCaches = import ../lib/caches.nix;
  tooling = import ../lib/tooling.nix { inherit pkgs; };
in
{
  inherit binaryCaches;

  # ----------------------------------------------------------------------------
  # SSH public keys
  # ----------------------------------------------------------------------------
  sshKeys = keys.users;

  # ----------------------------------------------------------------------------
  # Base packages (system-wide)
  # ----------------------------------------------------------------------------
  basePackages = with pkgs; [
    curl
    wget
    git
    htop
    vim
  ];

  # ----------------------------------------------------------------------------
  # Font packages
  # ----------------------------------------------------------------------------
  fonts = with pkgs; [
    maple-mono.NF-CN
    nerd-fonts.jetbrains-mono
    sarasa-gothic
    source-han-sans
    source-han-serif
  ];

  # ----------------------------------------------------------------------------
  # Nix development tools
  # ----------------------------------------------------------------------------
  nixTooling = tooling.nix;

  # ----------------------------------------------------------------------------
  # Nix settings
  # ----------------------------------------------------------------------------
  nixSettings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    keep-outputs = false;
    keep-derivations = false;
    download-buffer-size = 1073741824; # 1 GB
  };

  # ----------------------------------------------------------------------------
  # Server inventory
  # ----------------------------------------------------------------------------
  servers = import ../lib/servers.nix;

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

  # ----------------------------------------------------------------------------
  # SSH configuration helpers
  # ----------------------------------------------------------------------------
  mkSshExtraConfig =
    lib: servers: sshKey:
    lib.concatMapStringsSep "\n" (server: ''
      Host ${server.name}
        HostName ${server.ip}
        Port ${toString server.port}
        User root
        IdentityFile ${sshKey}
    '') servers;

  mkSshKnownHosts =
    lib: servers:
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
