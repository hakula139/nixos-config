# ==============================================================================
# OMP Extensions
# ==============================================================================

{
  pkgs,
}:

{
  telegram = pkgs.fetchFromGitHub {
    owner = "TerrifiedBug";
    repo = "omp-telegram";
    rev = "0ce609d7e019f32a7ea734b35aa87dbb1190f990"; # v0.13.0
    hash = "sha256-N7Fv/ZA2C5hjXgXqoAWWePFFoKgPnD5MxgFfzmep4gg=";
  };
}
