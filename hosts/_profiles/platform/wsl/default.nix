# ==================================================================================================
# WSL Platform Profile (NixOS-WSL)
# ==================================================================================================

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
  userManagerUnit = "user@${toString config.users.users.${userName}.uid}.service";

  # Docker Desktop's distro integration installs its credential helper in /usr/bin, which NixOS
  # sessions outside WSL init (such as SSH) lack on PATH.
  dockerCredentialDesktop = pkgs.linkFarm "docker-credential-desktop" {
    "bin/docker-credential-desktop.exe" = "/usr/bin/docker-credential-desktop.exe";
  };
in
{
  imports = [
    inputs.nixos-wsl.nixosModules.default
    repo.modules.nixos
  ];

  # ------------------------------------------------------------------------------------------------
  # NixOS-WSL identity
  # ------------------------------------------------------------------------------------------------
  wsl = {
    enable = true;
    defaultUser = userName;
    wslConf.user.default = userName;
    # Preserve WSLInterop when systemd-binfmt rewrites binfmt entries. Without it, cmd.exe /
    # powershell.exe fail to execute.
    interop.register = true;
    docker-desktop.enable = true;
  };

  # ------------------------------------------------------------------------------------------------
  # WSL-inert network knobs
  # ------------------------------------------------------------------------------------------------
  boot.kernel.sysctl = {
    "net.core.default_qdisc" = lib.mkForce null;
    "net.ipv4.tcp_congestion_control" = lib.mkForce null;
  };

  # ------------------------------------------------------------------------------------------------
  # Networking
  # ------------------------------------------------------------------------------------------------
  networking = {
    domain = lib.mkForce null;
  };

  # ------------------------------------------------------------------------------------------------
  # Containers
  # ------------------------------------------------------------------------------------------------
  environment.systemPackages = [
    dockerCredentialDesktop
  ];

  # Home Manager installs rootless podman as a plain package, which reads its signature policy from
  # /etc/containers/policy.json and refuses to pull or build without one. pasta maps
  # host.containers.internal to the host loopback, so containers reach a loopback-only proxy bind.
  virtualisation.containers = {
    enable = true;

    containersConf.settings.network.pasta_options = [
      "--map-host-loopback"
      "169.254.1.2"
    ];
  };

  # ------------------------------------------------------------------------------------------------
  # Services
  # ------------------------------------------------------------------------------------------------
  hakula.services.earlyoom.enable = true;

  # ------------------------------------------------------------------------------------------------
  # User session
  # ------------------------------------------------------------------------------------------------
  # logind under NixOS-WSL sees `Linger=yes` but doesn't actually call StartUnit on
  # user@<uid>.service, so the user manager stays dead and `wsl.exe` fails to attach to a session.
  # Pull it into multi-user.target to start it unconditionally at boot.
  systemd.targets.multi-user.wants = [
    userManagerUnit
  ];

  # systemd 258 + WSL2 sd-executor returns spurious EBUSY on user@<uid>.service despite the user
  # manager actually running. Clear the false-failed state.
  # Upstream: microsoft/WSL#13826, nix-community/NixOS-WSL#888.
  systemd.services.reset-user-manager-failed = {
    description = "Clear false-failed state on ${userManagerUnit}";
    wantedBy = [
      "multi-user.target"
    ];
    after = [
      "multi-user.target"
    ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe' pkgs.systemd "systemctl"} reset-failed ${userManagerUnit}";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Secrets
  # ------------------------------------------------------------------------------------------------
  age.identityPaths = [ "/home/${userName}/.ssh/id_ed25519" ];
}
