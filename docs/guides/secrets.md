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

Use an interactive terminal for manual edits and re-keying. With non-interactive stdin, `agenix -e` reads replacement plaintext from stdin, so empty input can erase a secret's contents. Re-keying is also restricted to interactive use by repository policy: never invoke `agenix -r` from a script or an assistant's shell tool.

Run from the repository root:

```bash
agenix -e secrets/<service>/<name>.age -i ~/.ssh/<private-key>
agenix -r -i ~/.ssh/<private-key>  # re-key after a recipient change
```

Filenames must match the recipient-rule keys. The root `secrets.nix` prefixes those keys with `secrets/`, so commands run from the repository root need that prefix. From inside `secrets/`, use `<service>/<name>.age`. This matching also applies to `agenix -d`, which reads the recipient rules before decrypting.
