# ==================================================================================================
# Worktree Hooks
# ==================================================================================================
# Claude Code routes its worktree features through Workmux, so a session, subagent, or background
# job receives a Workmux handle and its directory lives beside the checkout.
# ==================================================================================================

{
  pkgs,
  sharedHooks,
}:

let
  runtimeInputs = [
    pkgs.git
    pkgs.workmux
  ];
in
{
  create = {
    event = "WorktreeCreate";
    type = "command";
    command = sharedHooks.mkNuHook {
      slug = "worktree-create";
      script = ./worktree-create.nu;
      inherit runtimeInputs;
    };
  };

  remove = {
    event = "WorktreeRemove";
    type = "command";
    command = sharedHooks.mkNuHook {
      slug = "worktree-remove";
      script = ./worktree-remove.nu;
      inherit runtimeInputs;
    };
  };
}
