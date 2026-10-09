# ==================================================================================================
# Git Configuration
# ==================================================================================================

{
  pkgs,
  ...
}:

{
  # ------------------------------------------------------------------------------------------------
  # Git Configuration
  # ------------------------------------------------------------------------------------------------
  programs.git = {
    enable = true;

    # ----------------------------------------------------------------------------------------------
    # Git Settings
    # ----------------------------------------------------------------------------------------------
    settings = {
      user = {
        name = "Hakula Chen";
        email = "i@hakula.xyz";
      };

      init.defaultBranch = "main";

      core = {
        eol = "lf";
        fileMode = true;
        # The default omits loose-object and reference, which an unclean WSL2 shutdown zeroes.
        fsync = "all";
      };

      pull.rebase = true;
      rebase = {
        autostash = true;
        updateRefs = true;
      };

      # Report a submodule only when its checked-out commit changes
      diff.ignoreSubmodules = "dirty";

      diff.algorithm = "histogram";

      push.autoSetupRemote = true;

      color.ui = "auto";

      # Remember merge conflict resolutions
      rerere.enabled = true;

      alias = {
        unstage = "reset HEAD --";
        undo = "reset --soft HEAD~1";
        last = "log -1 HEAD --stat";
        contributors = "shortlog -sn";
      };
    };

    # ----------------------------------------------------------------------------------------------
    # Git LFS
    # ----------------------------------------------------------------------------------------------
    lfs.enable = true;

    # ----------------------------------------------------------------------------------------------
    # Global Gitignore
    # ----------------------------------------------------------------------------------------------
    ignores = [
      # macOS
      ".DS_Store"
      ".AppleDouble"
      ".LSOverride"
      "._*"

      # Editor swap / backup files
      "*.swp"
      "*.swo"
      "*~"

      # Editor / assistant local settings
      ".agents/plans"
      ".claude/agent-memory-local"
      ".claude/plans"
      ".claude/settings.local.json"
      ".claude/worktrees"
      ".cursor/plans"
    ];
  };

  # ------------------------------------------------------------------------------------------------
  # GitHub CLI
  # ------------------------------------------------------------------------------------------------
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # GitLab CLI
  # ------------------------------------------------------------------------------------------------
  home.packages = [ pkgs.glab ];

  # ------------------------------------------------------------------------------------------------
  # Delta - Better diff viewer
  # ------------------------------------------------------------------------------------------------
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      syntax-theme = "Dracula";
    };
  };
}
