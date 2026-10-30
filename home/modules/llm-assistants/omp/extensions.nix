# ==================================================================================================
# OMP Extensions
# ==================================================================================================

{
  pkgs,
}:

{
  telegram = pkgs.fetchFromGitHub {
    owner = "TerrifiedBug";
    repo = "omp-telegram";
    rev = "4f9f288f44dfa5dc8afed4f245edceb926d4a54a"; # v0.14.2
    hash = "sha256-YD6RODgaSCFjD6J0d3KJgbIY/Ekqs4GfZScI+mxhZrM=";
  };
}
