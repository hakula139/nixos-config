# ==================================================================================================
# Nix Garbage Collection
# ==================================================================================================

{
  platformSettings,
  ...
}:

{
  programs.nh.clean = {
    enable = true;
    dates = "daily";
    extraArgs = platformSettings.nhCleanArgs;
  };
}
