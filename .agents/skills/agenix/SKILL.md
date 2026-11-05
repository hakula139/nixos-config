---
name: agenix
description: >-
  Declare, decrypt, edit, re-key, and check this repository's agenix secrets without overwriting
  one by accident. Use when a task touches a secret, its declaration, or its recipient rules.
---

# agenix

Secrets are encrypted with [agenix](https://github.com/ryantm/agenix). Consumers read the decrypted path at runtime because values read during evaluation end up in the world-readable Nix store.

## Declare

System modules (NixOS, Darwin, system-manager) declare `age.secrets.<attr> = repoLib.secrets.mkSecret { name = "<service>/<secret>"; }`, whose `name` selects `secrets/<service>/<secret>.age`. Read the decrypted destination from `config.age.secrets.<attr>.path`, because agenix derives that path from the attribute key regardless of `name` unless `path` is overridden.

Home Manager modules declare `hakula.secrets.required."<service>/<secret>" = { };`, then read the path through the `secretPath` module argument, which rejects undeclared requirements. By default, the requirement key selects both `secrets/<service>/<secret>.age` and `/run/agenix/<service>/<secret>`. Override `name` to select a different encrypted source without changing the destination, and override `path` when a consumer requires a fixed location.

Reuse one logical key per encrypted source. Recipients live in `secrets/agenix-rules.nix`, with the keys they name in `secrets/keys.nix`.

## Edit and re-key

Use an interactive terminal for manual edits, and pipe into `agenix -e` only when you mean to replace a secret. Without a TTY on stdin, `agenix -e` skips decryption and the editor, then encrypts stdin as the new plaintext, so an empty pipe erases the secret.

Re-keying ignores stdin and works without a TTY. `agenix -r` re-encrypts every file the rules name for that rule's recipients, and if the identity cannot decrypt a file, the run stops there, leaving earlier files re-keyed and the rest unchanged. Run `agenix -c` afterwards to confirm that each file's recipients match its rule.

Run agenix from the repository root in the dev shell (`nix develop`), whose CLI matches the pinned version:

```bash
agenix -e secrets/<service>/<name>.age -i ~/.ssh/<private-key>
agenix -r -i ~/.ssh/<private-key>  # re-key after a recipient change
agenix -c                          # check recipients against the rules
```

Paths, including for `agenix -d`, resolve relative to the nearest `agenix-rules.nix` in the current directory or a parent. Because the rule keys must match the filenames, include the `secrets/` prefix when running from the repository root and omit it inside `secrets/`.
