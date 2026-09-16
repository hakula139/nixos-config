# Bootstrap

Use these steps to install a managed configuration or build the `devvm` image. For subsequent updates, use [`nixsw`](../../README.md#applying-a-configuration) for local server and workstation configurations and `nixdp` for server deployments. Commands with a `.#...` flake reference run from the repository root.

## NixOS server

NixOS servers partition their disks with [disko](https://github.com/nix-community/disko) and install over SSH via [nixos-anywhere](https://github.com/nix-community/nixos-anywhere). Provision one from a workstation with the flake checked out:

```bash
nix run github:nix-community/nixos-anywhere -- --flake '.#us-1' root@<host>
```

Next, verify SSH access to the inventory hosts and run these commands from the repository checkout on a managed workstation:

```bash
nixdp
nixdp --on us-4
nixdp --on @cloudcone
```

`nixdp` is the shared Zsh alias for `colmena apply`, accepting Colmena flags to run deployments directly from the current checkout with normal Nix cache and build behavior. The pinned CLI is installed on managed hosts and accessible through `nix develop`.

Inventory and deployment metadata live in `data/servers.nix`. Because every proxy node is also a deploy target, verify which route is in use before running a fleet-wide apply.

## NixOS-WSL workstation

`wsl` is a full NixOS workstation under WSL2 via [NixOS-WSL](https://github.com/nix-community/NixOS-WSL). Build and run the tarball builder on x86_64 Linux:

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

`devvm` packages its NixOS system closure as a Docker image for transfer to restricted networks. The [Compose file](../../hosts/images/devvm/docker-compose.yml) also requires host files and directories for credentials, workspace data, and the Docker socket. Runtime package downloads, including those started by `npx` and `uvx`, still need network access or a populated cache.

Build the image with Nix, then load and start it with Docker:

```bash
nix build '.#packages.x86_64-linux.devvm-docker'
docker load < result
docker compose -f hosts/images/devvm/docker-compose.yml up -d
```

Attach with the VS Code / Cursor Dev Containers command.
