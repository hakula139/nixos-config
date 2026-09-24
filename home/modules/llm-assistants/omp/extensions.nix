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
    rev = "03f5907ffef0d3698fb897cc769570082bd8d1e0"; # v0.14.0
    hash = "sha256-bbxBvpMGhivrTvwHwEQJASann828NomY4N/0uwa1cqs=";
  };
}
