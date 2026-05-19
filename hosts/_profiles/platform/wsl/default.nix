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

    # systemd-binfmt drops WSL's mini_init-registered WSLInterop entry
    # when `boot.binfmt.registrations` is non-empty, leaving cmd.exe /
    # powershell.exe / wslpath broken with `Exec format error`. Setting
    # `interop.register` re-adds WSLInterop alongside the systemd-binfmt
    # rewrite. See nix-community/NixOS-WSL#64.
    interop.register = true;
    docker-desktop.enable = true;
  };

  # ----------------------------------------------------------------------------
  # Disarm baseline knobs that don't apply under WSL
  # ----------------------------------------------------------------------------
  # NixOS-WSL turns off boot.kernel, boot.modprobeConfig, and console
  # (wsl-distro.nix:68-78). The baseline at modules/nixos/default.nix
  # still writes values that would land on disk via /etc/sysctl.d and
  # /etc/modprobe.d even though the Microsoft-supplied kernel ignores
  # them. Force the four BBR/swappiness keys to null per-key so future
  # additions to the baseline flow through unchanged.
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = lib.mkForce null;
    "net.ipv4.tcp_congestion_control" = lib.mkForce null;
    "vm.swappiness" = lib.mkForce null;
    "vm.vfs_cache_pressure" = lib.mkForce null;
  };
  boot.extraModprobeConfig = lib.mkForce "";

  # ----------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------
  # WSL controls /etc/resolv.conf via `wsl.wslConf.network.generateResolvConf`
  # (default true). NixOS-WSL warns at eval time if `networking.nameservers`
  # is non-empty alongside that flag (wsl-distro.nix:226), so leave the
  # nameservers list alone. Silently forcing it to [] would swallow that
  # warning if a future module set a nameserver.
  networking = {
    domain = lib.mkForce null;
  };

  # ----------------------------------------------------------------------------
  # Secrets
  # ----------------------------------------------------------------------------
  # NixOS-WSL doesn't start sshd by default, so agenix's
  # /etc/ssh/ssh_host_ed25519_key is never generated. Use the user key,
  # matching _profiles/platform/container.
  age.identityPaths = [ "/home/${userName}/.ssh/id_ed25519" ];

  # Without this check, a missing identity falls through to agenix's
  # "no readable identities found!" warning on stderr and per-secret
  # decryption errors, leaving runtime services (claude-code, mihomo,
  # ...) silently broken. Fail activation up-front instead, before
  # agenixNewGeneration runs.
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
