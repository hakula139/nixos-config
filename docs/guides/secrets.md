# Secrets

Secrets are encrypted with [agenix](https://github.com/ryantm/agenix). `lib/secrets.nix` has two contracts.

System modules (NixOS, Darwin, system-manager) declare:

```nix
age.secrets.<attr> = secrets.mkSecret { name = "<service>/<secret>"; owner = "..."; };
```

Home Manager modules declare a requirement and resolve it through the `secretPath` module argument:

```nix
hakula.secrets.required."<service>/<secret>" = { };
```

## Conventions

Decrypted paths mirror the `secrets/` tree, so `secrets/mihomo/secret.age` becomes `/run/agenix/mihomo/secret`.

- Logical key first. Override `name` only when the encrypted source differs from the logical key, and `path` only when a tool demands a fixed location (WakaTime wants `~/.wakatime.cfg`).
- One canonical location per secret, so never reference the same encrypted file under two logical keys. Collisions are caught at evaluation.
- For mihomo-style substitution into YAML, match against `ENVIRON[]` in `awk` so `|`, `&`, `\`, and `'` survive, then validate the merged config before an atomic swap.

Never print a decrypted value. Test presence with `[[ -s <path> ]]` or pipe straight into the consuming command.

## Editing

```bash
cd secrets
agenix -e <service>/<name>.age -i ~/.ssh/<private-key>
agenix -r -i ~/.ssh/<private-key>                       # re-key after a recipient change
```

## The `agenix -r` TTY trap

Re-keying after a recipient change in `secrets/keys.nix` **must** run from an interactive terminal. The script checks `[ -t 0 ]` and overrides `EDITOR` to `cp -- /dev/stdin` when stdin lacks a TTY, which silently empties every secret before re-encrypting it. Never invoke it from a script or an assistant's shell tool.
