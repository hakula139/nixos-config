# Secrets

Secrets are encrypted with [agenix](https://github.com/ryantm/agenix). `lib/secrets.nix` provides the helpers used by system services and Home Manager.

System modules (NixOS, Darwin, system-manager) declare:

```nix
age.secrets.<attr> = repoLib.secrets.mkSecret {
  name = "<service>/<secret>";
  owner = "...";
};
```

The helper's `name` selects the encrypted source. Read the decrypted destination from `config.age.secrets.<attr>.path`, since agenix derives it from the attribute key unless `path` is overridden.

Home Manager modules declare a requirement and resolve it through the `secretPath` module argument:

```nix
hakula.secrets.required."<service>/<secret>" = { };
```

## Conventions

Home Manager secret requirements default to paths mirroring the `secrets/` tree, so `secrets/mihomo/secret.age` becomes `/run/agenix/mihomo/secret`.

- Logical key first. Override `name` only when the encrypted source differs from the logical key, and `path` only when a tool demands a fixed location (WakaTime wants `~/.wakatime.cfg`).
- Keep one logical key per encrypted source. Home Manager secret requirements also need unique destination paths, which are checked at evaluation to prevent one decryption overwriting another.
- For mihomo-style substitution into YAML, match against `ENVIRON[]` in `awk` so `|`, `&`, `\`, and `'` survive, then validate the merged config before an atomic swap.

Never print a decrypted value. Test presence with `[[ -s <path> ]]` or pipe straight into the consuming command.

## Editing and re-keying

Use an interactive terminal for manual secret editing. With non-interactive stdin, `agenix -e` reads replacement plaintext from stdin, so empty input can overwrite a secret with empty content. Repository policy also reserves `agenix -r` for an interactive terminal. Never invoke it from a script or an assistant's shell tool.

Run from the repository root:

```bash
agenix -e secrets/<service>/<name>.age -i ~/.ssh/<private-key>
agenix -r -i ~/.ssh/<private-key>  # re-key after a recipient change
```

The root `secrets.nix` prefixes filenames in the existing recipient rules with `secrets/`. Commands from inside `secrets/` still use `<service>/<name>.age`. This path matching also applies to `agenix -d`, which reads the recipient rules before decrypting.

The locked agenix version bypasses the editor during re-keying. Its stdin replacement behavior applies to `agenix -e`.
