# Secrets

Secrets are encrypted with [agenix](https://github.com/ryantm/agenix). `lib/secrets.nix` provides the helpers used by system services and Home Manager.

Never print a decrypted value. Test presence with `[[ -s <path> ]]` or pipe straight into the consuming command.

## System modules

System modules (NixOS, Darwin, system-manager) declare:

```nix
age.secrets.<attr> = repoLib.secrets.mkSecret {
  name = "<service>/<secret>";
  owner = "...";
};
```

The helper's `name` selects `secrets/<service>/<secret>.age`. Read the decrypted destination from `config.age.secrets.<attr>.path`: agenix derives it from the attribute key, independently of `name`, unless `path` is overridden.

## Home Manager

Declare a requirement before reading its path through the `secretPath` module argument:

```nix
hakula.secrets.required."<service>/<secret>" = { };
```

Consumers use `secretPath "<service>/<secret>"`, which resolves the declared destination and rejects undeclared requirements. By default, the requirement key selects both `secrets/<service>/<secret>.age` and `/run/agenix/<service>/<secret>`.

Override `name` to select a different encrypted source without changing the destination. Override `path` when a consumer requires a fixed location, such as WakaTime's `~/.wakatime.cfg`.

Reuse one logical key per encrypted source. Destination paths must also be unique: evaluation rejects collisions to prevent one decryption overwriting another.

## Editing and re-keying

Use an interactive terminal for manual edits. Without a TTY on stdin, `agenix -e` skips decryption and the editor, then encrypts stdin as the new plaintext. An empty pipe therefore erases the secret. Pipe into `agenix -e` only when you deliberately want to replace a secret.

Re-keying works without a TTY, so scripts and assistants can run it. The pinned `agenix -r` ignores stdin. It decrypts each file named in the recipient rules with the given identity, then re-encrypts the same plaintext for that rule's recipients, changing every listed `.age` file. If the identity cannot decrypt a file, the run stops and that file remains unchanged, while files processed before it retain their new encryption. Rules without a file are skipped. Afterwards, run `agenix -c` to confirm that each file's recipients match its rule.

Use the repository's development shell (`nix develop`) so the CLI matches the pinned agenix version. Run from the repository root:

```bash
agenix -e secrets/<service>/<name>.age -i ~/.ssh/<private-key>
agenix -r -i ~/.ssh/<private-key>  # re-key after a recipient change
agenix -c                          # check recipients against the rules
```

Filenames must match the recipient-rule keys. Agenix discovers `agenix-rules.nix` in the current directory or a parent. Secret paths are relative to the selected rules file. The root `agenix-rules.nix` prefixes rule keys with `secrets/`, so commands from the repository root need that prefix. From inside `secrets/`, its own `agenix-rules.nix` uses `<service>/<name>.age`. For an explicit rules file, set `AGENIX_RULES` to its path. This matching also applies to `agenix -d`, which reads the recipient rules before decrypting.
