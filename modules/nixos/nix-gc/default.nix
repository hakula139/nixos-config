# ==================================================================================================
# Nix Garbage Collection
# ==================================================================================================

{
  platformSettings,
  ...
}:

{
  nix.optimise.automatic = true;

  programs.nh.clean = {
    enable = true;
    dates = "daily";
    extraArgs = platformSettings.nhCleanArgs;
  };
}
