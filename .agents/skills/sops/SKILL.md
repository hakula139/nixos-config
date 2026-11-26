---
name: sops
description: >-
  Declare, decrypt, edit, and re-key this repository's sops-nix secrets without overwriting or
  exposing plaintext. Use when a task touches a secret, its catalog entry, or `.sops.yaml`
  recipient rules.
---

# sops

Secrets are encrypted with [sops](https://github.com/getsops/sops) and decrypted at runtime into `/run/secrets/` via [sops-nix](https://github.com/Mic92/sops-nix).

## Declare

Register each secret in `lib/secrets.nix` (`catalog`):

- `bundle` / `yaml` for keys inside a domain YAML bundle.
- `wholeFile "<file>" "<format>"` for native whole-file formats (`dotenv`, `ini`, `json`, `binary`).

Declare and consume by layer:

| Layer                           | Declaration                                           | Path lookup                       |
| ------------------------------- | ----------------------------------------------------- | --------------------------------- |
| NixOS / Darwin / system-manager | `repoLib.secrets.mkSecret`                            | `config.sops.secrets.<attr>.path` |
| Home Manager                    | `hakula.secrets.required."<service>/<secret>" = { };` | `secretPath "<service>/<secret>"` |

```nix
# System module (optional overrides: owner, group, mode, path, restartUnits, reloadUnits)
sops.secrets.<attr> = repoLib.secrets.mkSecret { name = "<service>/<secret>"; };

# Home Manager module (optional overrides: name, path; each path must be unique)
hakula.secrets.required."<service>/<secret>" = { };
```

- `sops-nix` derives `/run/secrets/<attr>` from the attribute key regardless of `name` unless `path` is overridden.
- `modules/shared/user-secrets` bridges `hakula.secrets.required` into user-owned `sops.secrets`.

## Recipients and identities

Rules and `age1...` recipients live in `.sops.yaml` (converted from SSH ed25519 keys in `data/keys.nix` via `ssh-to-age`):

| Host class                                       | Runtime identity path           |
| ------------------------------------------------ | ------------------------------- |
| NixOS servers (`us-1`, `us-4`)                   | `/etc/ssh/ssh_host_ed25519_key` |
| Workstations (`wsl`, `wsl-non-nixos`, `macbook`) | `~/.ssh/id_ed25519`             |
| `devvm` container                                | `/root/.config/sops/identity`   |

## Commands

Run from the repository root inside `nix develop`. Store converted age keys in `~/.config/sops/age/keys.txt` (`0600`) to omit `SOPS_AGE_KEY`, or pass an SSH key inline per command:

```bash
# Interactive edit
sops secrets/<file>

# Non-interactive single-key update (nested YAML keys indexed by segment)
sops set --value-stdin secrets/<file> '["<section>"]["<key>"]' <<<"\"<value>\""

# Re-key after .sops.yaml recipient changes
sops updatekeys secrets/<file>

# Rotate data key after revoking a compromised key
sops rotate -i secrets/<file>

# Inject decrypted env into a command without eval or shell pollution
sops exec-env secrets/<file>.env '<command>'

# One-off SSH key prefix (when not in ~/.config/sops/age/keys.txt)
SOPS_AGE_KEY="$(ssh-to-age -private-key -i ~/.ssh/<private-key>)" sops secrets/<file>
```

- Pass `--input-type binary` (and `--output-type binary` when editing) for extensionless binary files such as `secrets/builders-ssh-key`.
- Never print decrypted values, leave plaintext files in the working tree, or overwrite a secret with empty stdin.
