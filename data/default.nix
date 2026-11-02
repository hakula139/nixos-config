# ==================================================================================================
# Shared Data
# ==================================================================================================

{
  backblaze = import ./backblaze.nix;
  caches = import ./caches.nix;
  corpHosts = import ./corp-hosts.nix;
  modelCatalog = import ./llm-models.nix;
  platformSettings = import ./platform-settings.nix;
  servers = import ./servers.nix;
  systemManagerPaths = import ./system-manager-paths.nix;
}
