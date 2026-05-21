# ==============================================================================
# WSL Platform Profile (NixOS-WSL)
# ==============================================================================

{
  config,
  pkgs,
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
  # User session
  # ----------------------------------------------------------------------------
  # logind under NixOS-WSL sees `Linger=yes` but doesn't actually call
  # StartUnit on user@<uid>.service, so the user manager stays dead and
  # `wsl.exe` fails to attach to a session. Pull it into multi-user.target
  # to start it unconditionally at boot.
  systemd.targets.multi-user.wants = [ "user@1000.service" ];

  # systemd 258 + WSL2 sd-executor returns spurious EBUSY on user@<uid>.service
  # despite the user manager actually running. Clear the false-failed state.
  # Upstream: microsoft/WSL#13826, nix-community/NixOS-WSL#888.
  systemd.services.reset-user-manager-failed = {
    description = "Clear false-failed state on user@1000.service";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl reset-failed user@1000.service";
    };
  };

  # ----------------------------------------------------------------------------
  # Secrets
  # ----------------------------------------------------------------------------
  age.identityPaths = [ "/home/${userName}/.ssh/id_ed25519" ];
}
