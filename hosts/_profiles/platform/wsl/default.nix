# ==============================================================================
# WSL Platform Profile (NixOS-WSL)
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
    # Preserve WSLInterop when systemd-binfmt rewrites binfmt entries.
    # Without it, cmd.exe / powershell.exe / wslpath fail to execute.
    interop.register = true;
    docker-desktop.enable = true;
  };

  # ----------------------------------------------------------------------------
  # WSL-inert baseline knobs
  # ----------------------------------------------------------------------------
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = lib.mkForce null;
    "net.ipv4.tcp_congestion_control" = lib.mkForce null;
    "vm.swappiness" = lib.mkForce null;
    "vm.vfs_cache_pressure" = lib.mkForce null;
  };

  # ----------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------
  networking = {
    domain = lib.mkForce null;
  };

  # ----------------------------------------------------------------------------
  # Secrets
  # ----------------------------------------------------------------------------
  age.identityPaths = [ "/home/${userName}/.ssh/id_ed25519" ];
}
