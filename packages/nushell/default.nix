# ==================================================================================================
# Nushell
# ==================================================================================================

{
  pkgs,
}:

pkgs.unstable.nushell.overrideAttrs (old: rec {
  version = "0.117.0";
  src = old.src.override {
    tag = version;
    hash = "sha256-+lA9T0Wa/K50qCfyGFdNlEmCZWCeBk8KcxIvDCKk2no=";
  };

  patches = [ ];
  cargoPatches = [ ];
  cargoHash = "sha256-0t1ubpyPiXucUlJ+Nwu2u3LZ15GtX6mF2kMy9HkbClw=";
  cargoDeps = pkgs.unstable.rustPlatform.fetchCargoVendor {
    inherit (old) pname;
    inherit src version;
    hash = cargoHash;
  };
})
