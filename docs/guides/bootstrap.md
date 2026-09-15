# Bootstrap

First-time setup per platform. Day-to-day local applies use the [`nixsw` alias](../../README.md#applying-a-configuration). Server fleet deployments use the CI-backed command below.

## NixOS server

NixOS servers partition their disks with [disko](https://github.com/nix-community/disko) and install over SSH via [nixos-anywhere](https://github.com/nix-community/nixos-anywhere). Provision one from a workstation with the flake checked out:

```bash
nix run github:nix-community/nixos-anywhere -- --flake '.#us-1' root@<host>
```

Afterwards, authenticate `gh` and ensure SSH access to the inventory hosts. Deploy from a workstation:

```bash
nix run .#deploy -- --reboot
nix run .#deploy -- --on us-4
nix run .#deploy -- --revision <full-commit-sha> --reboot
```

The command selects public `main` once, waits for the selected servers' CI artifacts, and fetches their runtime closures without building. It runs the configured restic backups before changing stateful hosts, then checks services, public endpoints, and proxy routes. Umami checks include public country / region collection with temporary test records. It stops on a cache miss, insufficient disk space, or failed health check. Resume with the printed revision after resolving the failure. It retains the previous system as a GC root until that host passes its checks, and does not delete generations or application data to make space.

On macOS it reads Clash Verge's runtime controller settings and tests an alternate REALITY route before disrupting the selected proxy server. Pass `--clash-config <path>` for another runtime configuration, or `--without-clash` when the workstation does not use Clash. A failed rollout leaves the healthy alternate selected. A successful rollout restores the original selection after testing it.

Local private overrides require a separate build and are excluded from this command. For manual deployment, enter `nix develop` to use the pinned Colmena CLI. Inventory and deployment metadata live in `data/servers.nix`.

## NixOS-WSL workstation

`wsl` is a full NixOS workstation under WSL2 via [NixOS-WSL](https://github.com/nix-community/NixOS-WSL). Build the import tarball from any host with the flake checked out:

```bash
nix build '.#nixosConfigurations.wsl.config.system.build.tarballBuilder'
sudo ./result/bin/nixos-wsl-tarball-builder    # produces ./nixos.wsl
```

Move `nixos.wsl` to the Windows side and import it (PowerShell):

```powershell
wsl --shutdown
wsl --install --from-file .\nixos.wsl    # WSL >= 2.4.4
wsl -d NixOS                             # first launch
```

On older WSL versions, use `wsl --import NixOS C:\WSL\NixOS .\nixos.wsl`.

Inside the new distro, copy the agenix identity from the Windows side and apply the managed configuration:

```bash
git clone https://github.com/hakula139/nixos-config ~/nixos-config
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cp /mnt/c/Users/<name>/.ssh/id_ed25519     ~/.ssh/id_ed25519
cp /mnt/c/Users/<name>/.ssh/id_ed25519.pub ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/id_ed25519

sudo nixos-rebuild switch --flake ~/nixos-config#wsl
```

## Non-NixOS Linux (System Manager)

`wsl-non-nixos` uses [system-manager](https://github.com/numtide/system-manager) to own the system profile, user shell integration, agenix secret activation, and the Home Manager activation service.

Install Nix with the Determinate Nix Installer, then bootstrap System Manager before the managed profile installs `system-manager` itself:

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
nix run '.#system-manager' -- switch --flake '.#wsl-non-nixos' --sudo
system-manager-health-check agenix-install-secrets.service home-manager-hakula.service
```

## macOS

`macbook` is a macOS workstation managed by [nix-darwin](https://github.com/LnL7/nix-darwin), including Homebrew cask installation.

Install Nix with the Determinate Nix Installer, then bootstrap nix-darwin:

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake '.#macbook'
```

## Docker image

`devvm` bakes a whole NixOS system closure into a Docker image, so every dependency ships inside it and the container comes up in an air-gapped environment.

Build the image with Nix, then load and start it with Docker:

```bash
nix build '.#packages.x86_64-linux.devvm-docker'
docker load < result
docker compose -f hosts/images/devvm/docker-compose.yml up -d
```

Attach with the VS Code / Cursor Dev Containers command.
