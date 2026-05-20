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
  boot.extraModprobeConfig = lib.mkForce "";

  # ----------------------------------------------------------------------------
  # Networking
  # ----------------------------------------------------------------------------
  networking = {
    domain = lib.mkForce null;
  };

  # ----------------------------------------------------------------------------
  # Secrets
  # ----------------------------------------------------------------------------
  # NixOS-WSL does not generate an ssh host key by default.
  age.identityPaths = [ "/home/${userName}/.ssh/id_ed25519" ];

  system.activationScripts = {
    # Let fresh imports create the login user before the agenix identity check.
    users.deps = lib.mkForce [ ];

    checkAgeIdentity = {
      deps = [
        "createSbin"
        "groups"
        "populateBin"
        "shimSystemd"
        "specialfs"
        "users"
      ];
      text = ''
        identity=/home/${userName}/.ssh/id_ed25519
        if [ ! -r "$identity" ]; then
          echo "ERROR: agenix identity $identity is missing or unreadable." >&2
          echo "Copy your private key from the Windows side before nixos-rebuild:" >&2
          echo "  mkdir -p ~/.ssh && chmod 700 ~/.ssh" >&2
          echo "  cp /mnt/c/Users/<name>/.ssh/id_ed25519     $identity" >&2
          echo "  cp /mnt/c/Users/<name>/.ssh/id_ed25519.pub $identity.pub" >&2
          echo "  chmod 600 $identity" >&2
          exit 1
        fi
      '';
    };

    agenixNewGeneration.deps = [ "checkAgeIdentity" ];
    agenixChown.deps = lib.mkAfter [ "agenixInstall" ];
  };
}
