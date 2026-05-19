# ==============================================================================
# WSL Platform Profile (NixOS-WSL)
# ==============================================================================
# Platform-shape overrides for hosts running under NixOS-WSL. Imports the
# upstream `nixosModules.default` and disarms the parts of `modules/nixos`
# that are tuned for bare-metal / VPS hosts and don't apply under WSL2's
# Microsoft kernel.
# ==============================================================================

{
  config,
  lib,
  inputs,
  repo,
  ...
}:

let
  userName = config.hakula.user.name;
in
{
  imports = [
    inputs.nixos-wsl.nixosModules.default
    repo.modules.nixos
  ];

  # ----------------------------------------------------------------------------
  # NixOS-WSL identity
  # ----------------------------------------------------------------------------
  wsl = {
    enable = true;
    defaultUser = userName;
    wslConf.user.default = userName;

    # systemd-binfmt drops WSL's mini_init-registered WSLInterop entry when
    # boot.binfmt.registrations is non-empty, leaving cmd.exe / powershell.exe /
    # wslpath broken with `Exec format error`. `interop.register = true`
    # explicitly re-adds WSLInterop to boot.binfmt.registrations so the
    # rewrite preserves it. See nix-community/NixOS-WSL#64.
    interop.register = true;

    # Wire up Docker Desktop integration: mounts /mnt/wsl/docker-desktop-*
    # bind paths and exposes the docker CLI from the Windows host.
    docker-desktop.enable = true;
  };

  # ----------------------------------------------------------------------------
  # Disarm baseline knobs that don't apply under WSL
  # ----------------------------------------------------------------------------
  # NixOS-WSL sets boot.kernel.enable = false (Microsoft supplies the kernel)
  # and boot.modprobeConfig.enable = false. The baseline (modules/nixos/default.nix)
  # writes options against those disabled subsystems; clear them.
  boot.kernel.sysctl = lib.mkForce { };
  boot.extraModprobeConfig = lib.mkForce "";

  # ----------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------
  # WSL controls /etc/resolv.conf via `wsl.wslConf.network.generateResolvConf`
  # (default true). NixOS's `networking.nameservers` would overwrite it.
  networking = {
    domain = lib.mkForce null;
    nameservers = lib.mkForce [ ];
    firewall.allowedTCPPorts = lib.mkForce [ ];
  };

  # ----------------------------------------------------------------------------
  # Secrets
  # ----------------------------------------------------------------------------
  # NixOS-WSL doesn't start sshd by default, so the agenix default
  # /etc/ssh/ssh_host_ed25519_key is never generated. Use the user key
  # instead — the same pattern _profiles/platform/container uses.
  age.identityPaths = [ "/home/${userName}/.ssh/id_ed25519" ];

  # If the identity is missing, agenix would fall through to "no readable
  # identities found!" on stderr and proceed with a WARNING per secret,
  # leaving runtime services (claude-code, mihomo, ...) silently broken.
  # Fail activation up-front with an actionable message instead. Runs
  # before agenixNewGeneration so the agenix output never reaches the user.
  system.activationScripts.checkAgeIdentity = {
    deps = [ "specialfs" ];
    text = ''
      identity=/home/${userName}/.ssh/id_ed25519
      if [ ! -r "$identity" ]; then
        echo "ERROR: agenix identity $identity is missing or unreadable." >&2
        echo "Copy your private key from the Windows side before nixos-rebuild:" >&2
        echo "  cp /mnt/c/Users/<name>/.ssh/id_ed25519     $identity" >&2
        echo "  cp /mnt/c/Users/<name>/.ssh/id_ed25519.pub $identity.pub" >&2
        echo "  chmod 600 $identity" >&2
        exit 1
      fi
    '';
  };

  system.activationScripts.agenixNewGeneration.deps = [ "checkAgeIdentity" ];
}
