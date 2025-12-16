{ ... }:

{
  # ============================================================================
  # Git Configuration
  # ============================================================================
  programs.git = {
    enable = true;

    # --------------------------------------------------------------------------
    # Git Settings
    # --------------------------------------------------------------------------
    settings = {
      # User Identity
      user = {
        name = "Hakula Chen";
        email = "i@hakula.xyz";
      };

      # Initialize with main branch
      init.defaultBranch = "main";

      # Core settings
      core = {
        eol = "lf";
        fileMode = true;
      };

      # Rebase on pull
      pull.rebase = true;

      # Ignore submodule changes in diff
      diff.ignoreSubmodules = "dirty";

      # Better diff algorithm
      diff.algorithm = "histogram";

      # Auto-setup remote tracking
      push.autoSetupRemote = true;

      # Colorful output
      color.ui = "auto";

      # Remember merge conflict resolutions
      rerere.enabled = true;

      # Aliases
      alias = {
        unstage = "reset HEAD --";
        undo = "reset --soft HEAD~1";
        last = "log -1 HEAD --stat";
        contributors = "shortlog -sn";
      };
    };

    # --------------------------------------------------------------------------
    # Git LFS
    # --------------------------------------------------------------------------
    lfs.enable = true;

    # --------------------------------------------------------------------------
    # Global Gitignore
    # --------------------------------------------------------------------------
    ignores = [
      # macOS
      ".DS_Store"
      ".AppleDouble"
      ".LSOverride"
      "._*"

      # IDEs
      ".cursor/plans"
      "*.swp"
      "*.swo"
      "*~"
    ];
  };

  # ============================================================================
  # Delta - Better diff viewer
  # ============================================================================
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
