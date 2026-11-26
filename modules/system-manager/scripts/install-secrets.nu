#!/usr/bin/env nu

# ==================================================================================================
# System Manager SOPS Secret Installer
# ==================================================================================================
# Decrypts configured SOPS secrets into /run/secrets during system-manager activation and prunes
# paths removed from the manifest.
# ==================================================================================================

use config-file.nu [save-atomic]

def extract-expr [key: string]: nothing -> string {
  $key
  | split row "/"
  | each {|part| $'["($part)"]' }
  | str join ""
}

def collect-age-keys [identity_paths: list<string>]: nothing -> string {
  mut keys = []
  for identity in $identity_paths {
    let readable = try {
      (open --raw $identity | into binary | length) > 0
    } catch {
      false
    }

    if not $readable {
      print -e $"warning: sops SSH identity not readable: ($identity)"
      continue
    }

    let key = (^ssh-to-age -private-key -i $identity | str trim)
    $keys = ($keys | append $key)
  }

  if ($keys | is-empty) {
    error make {msg: $"No readable SSH identities found in: ($identity_paths | str join ' ')"}
  }

  $"($keys | str join (char nl))\n"
}

def decrypt-secret [secret: record, key_file: path] {
  let target = $secret.path
  let tmp = $"($target).tmp"
  let target_dir = ($target | path dirname)

  print $"decrypting ($secret.name) to ($target)"
  if not ($target_dir | path exists) {
    ^install -dm0700 $target_dir
    ^chown $"($secret.owner):($secret.group)" $target_dir
  }
  rm --force $tmp

  let is_whole_file = ($secret.format == "binary") or ($secret.key | is-empty)
  let args = if $is_whole_file {
    [
      decrypt
      --input-type $secret.format
      --output-type $secret.format
      --output $tmp
      $secret.sopsFile
    ]
  } else {
    [
      decrypt
      --input-type $secret.format
      --extract (extract-expr $secret.key)
      --output $tmp
      $secret.sopsFile
    ]
  }

  with-env {SOPS_AGE_KEY_FILE: $key_file} {
    ^sops ...$args
  }

  ^chmod $secret.mode $tmp
  ^chown $"($secret.owner):($secret.group)" $tmp
  ^mv -f $tmp $target
}

def prune-stale [managed_paths_file: path, desired_paths: list<string>] {
  if ($managed_paths_file | path exists) {
    let previous = (open --raw $managed_paths_file | lines | where {|line| $line | is-not-empty })
    for managed_path in $previous {
      if $managed_path not-in $desired_paths {
        rm --force $managed_path
      }
    }
  }

  mkdir ($managed_paths_file | path dirname)
  save-atomic $"($desired_paths | str join (char nl))\n" $managed_paths_file --mode "0644"
}

# Install all configured SOPS secrets and prune removed paths.
def main [
  --config: path # Wrapper-supplied JSON with identities, directories, and secret specs
] {
  let cfg = (open $config)
  let age_keys = (collect-age-keys $cfg.identityPaths)

  let key_file = (mktemp)
  ^chmod 600 $key_file
  $age_keys | save --force $key_file

  try {
    ^install -dm0751 $cfg.secretsDir

    for secret in $cfg.secrets {
      decrypt-secret $secret $key_file
    }

    prune-stale $cfg.managedPathsFile ($cfg.secrets | get path)
  } catch {|err|
    rm --force $key_file
    error make {msg: ($err.msg? | default "sops-install-secrets failed")}
  }

  rm --force $key_file
}
