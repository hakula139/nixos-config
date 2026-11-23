# ==================================================================================================
# Docker Container Profile
# ==================================================================================================

{
  config,
  repo,
  ...
}:

let
  username = config.hakula.user.name;
in

{
  imports = [
    repo.modules.nixos
  ];

  # ------------------------------------------------------------------------------------------------
  # Container Configuration
  # ------------------------------------------------------------------------------------------------
  boot.isContainer = true;

  # ------------------------------------------------------------------------------------------------
  # Systemd
  # ------------------------------------------------------------------------------------------------
  systemd = {
    # Rootless containers cannot mount debugfs or tracefs, even with a user-namespace CAP_SYS_RAWIO.
    suppressedSystemUnits = [
      "sys-kernel-debug.mount"
      "sys-kernel-tracing.mount"
    ];

    tmpfiles.rules = [
      "d /nix/var/nix/profiles/per-user/${username} 0755 ${username} root -"
    ];
  };

  # ------------------------------------------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------------------------------------------
  networking = {
    firewall.enable = false;
    # Docker mounts /etc/resolv.conf read-only, so resolvconf and stage 2 must not rewrite it.
    resolvconf.enable = false;
    useDHCP = false;
  };

  # ------------------------------------------------------------------------------------------------
  # Secrets
  # ------------------------------------------------------------------------------------------------
  # Agenix needs an identity path for secret decryption. Containers don't run openssh, so we use a
  # dedicated key stored in the persistent Docker volume.
  age.identityPaths = [ "/root/.config/agenix/identity" ];
}
