# Bootstrap

First-time setup per platform. Day-to-day applies use the `nixsw` zsh alias everywhere, so this page only covers the steps that precede a managed configuration.

## NixOS server

```bash
nix run github:nix-community/nixos-anywhere -- --flake '.#us-1' root@<host>
```

Afterwards, deploy from a workstation with Colmena. `--on` takes a host name or a provider tag:

```bash
colmena apply
colmena apply --on us-4
colmena apply --on @cloudcone
```

Inventory and deployment metadata live in `data/servers.nix`. Every proxy node is also a deploy target, so check what is live before a fleet-wide apply.

## NixOS-WSL workstation

`wsl` is a full NixOS workstation under WSL2 via [NixOS-WSL](https://github.com/nix-community/NixOS-WSL). Build the import tarball from any host with the flake checked out:

```bash
nix build '.#nixosConfigurations.wsl.config.system.build.tarballBuilder'
sudo ./result/bin/nixos-wsl-tarball-builder           # produces ./nixos.wsl
```

Move `nixos.wsl` to the Windows side and import it (PowerShell):

```powershell
wsl --shutdown
wsl --install --from-file .\nixos.wsl                 # WSL >= 2.4.4
wsl -d NixOS                                          # first launch
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

```bash
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake '.#macbook'
```

## Docker image

```bash
nix build '.#packages.x86_64-linux.devvm-docker'
docker load < result
docker compose -f hosts/images/devvm/docker-compose.yml up -d
```

Attach with the VS Code / Cursor Dev Containers command.
