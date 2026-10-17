# ==================================================================================================
# Nix Garbage Collection
# ==================================================================================================

{
  defaults,
  ...
}:

{
  nix.optimise.automatic = true;

  programs.nh.clean = {
    enable = true;
    dates = "daily";
    extraArgs = defaults.nixCleanArgs;
  };
}
