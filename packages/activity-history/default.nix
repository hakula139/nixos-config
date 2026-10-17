# ==================================================================================================
# Activity History
# ==================================================================================================

{
  pkgs,
}:

pkgs.writeNuApplication {
  name = "activity-history";
  src = ./.;
  runtimeInputs = with pkgs; [
    git
    zstd
  ];
  meta.description = "Daily activity history of agent sessions, commits, and meetings";
}
