{ pkgs, ... }:

# ==============================================================================
# Shared Configuration (cross-platform)
# ==============================================================================

let
  keys = import ../secrets/keys.nix;
  tooling = import ../lib/tooling.nix { inherit pkgs; };
in
{
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
  # Binary caches
  # ----------------------------------------------------------------------------
  binaryCaches =
    let
      caches = [
        {
          url = "https://hakula.cachix.org";
          key = "hakula.cachix.org-1:7zwB3fhMfReHdOjh6DmnaLXgqbPDBcojvN9F+osZw0k=";
        }
        {
          url = "https://cache.numtide.com";
          key = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
        }
      ];
    in
    {
      substituters = map (c: c.url) caches;
      trusted-public-keys = map (c: c.key) caches;
    };

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
  servers = {
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
      ip = "64.186.229.64";
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
  };

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
    }) (builtins.filter (s: s.isBuilder) servers);

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
        name = server.name;
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
