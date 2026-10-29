# Secrets

Secrets are encrypted with [agenix](https://github.com/ryantm/agenix).

Consumers read the decrypted path at runtime because values read during evaluation end up in the world-readable Nix store.

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

Reuse one logical key per encrypted source.

## Editing and re-keying

Use an interactive terminal for manual edits. Without a TTY on stdin, `agenix -e` skips decryption and the editor, then encrypts stdin as the new plaintext. An empty pipe therefore erases the secret. Pipe into `agenix -e` only when you deliberately want to replace a secret.

Re-keying ignores stdin and works without a TTY. `agenix -r` re-encrypts every file the rules name for that rule's recipients. If the identity cannot decrypt a file, the run stops there, leaving earlier files re-keyed and the rest unchanged. Run `agenix -c` afterwards to confirm each file's recipients match its rule.

Use the repository's development shell (`nix develop`) so the CLI matches the pinned agenix version. Run from the repository root:

```bash
agenix -e secrets/<service>/<name>.age -i ~/.ssh/<private-key>
agenix -r -i ~/.ssh/<private-key>  # re-key after a recipient change
agenix -c                          # check recipients against the rules
```

Paths resolve against the nearest `agenix-rules.nix` in the current directory or a parent, whose keys must match the filenames, so from the repository root include the `secrets/` prefix and inside `secrets/` omit it. `agenix -d` resolves paths the same way.
