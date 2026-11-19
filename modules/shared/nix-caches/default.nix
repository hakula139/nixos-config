# ==================================================================================================
# Nix Binary Caches
# ==================================================================================================

{
  config,
  lib,
  caches,
  ...
}:

let
  selected = lib.attrVals config.hakula.nix.caches caches;
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options.hakula.nix.caches = lib.mkOption {
    type = lib.types.listOf (lib.types.enum (lib.attrNames caches));
    default = lib.attrNames caches;
    description = "Names from data/caches.nix whose substituters and public keys the host trusts";
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config.nix.settings = {
    extra-substituters = lib.catAttrs "url" selected;
    extra-trusted-public-keys = lib.catAttrs "key" selected;
  };
}
