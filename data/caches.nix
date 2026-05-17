# ==============================================================================
# Binary Caches
# ==============================================================================

let
  caches = [
    {
      url = "https://hakula.cachix.org";
      key = "hakula.cachix.org-1:7zwB3fhMfReHdOjh6DmnaLXgqbPDBcojvN9F+osZw0k=";
    }
    {
      url = "https://cache.numtide.com";
      key = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
    }
  ];
in
{
  substituters = map (c: c.url) caches;
  trusted-public-keys = map (c: c.key) caches;
}
