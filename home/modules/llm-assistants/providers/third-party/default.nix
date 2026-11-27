# ==================================================================================================
# Third-Party Relay Providers
# ==================================================================================================

{
  lib,
  secretPath,
}:

let
  relays = map (file: import file { inherit secretPath; }) [
    ./ikuncode.nix
    ./yescode.nix
  ];
in
{
  providers = lib.mergeAttrsList (map (relay: relay.providers) relays);
  profiles = lib.mergeAttrsList (map (relay: relay.profiles) relays);
  requiredSecrets = lib.unique (lib.concatMap (relay: relay.requiredSecrets) relays);
}
