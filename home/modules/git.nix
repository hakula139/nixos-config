{ ... }:

{
  # ============================================================================
  # Git Configuration
  # ============================================================================
  programs.git = {
    enable = true;

    # --------------------------------------------------------------------------
    # User Identity
    # --------------------------------------------------------------------------
    userName = "Hakula Chen";
    userEmail = "i@hakula.xyz";

    # --------------------------------------------------------------------------
    # Core Settings
    # --------------------------------------------------------------------------
    extraConfig = {
      init.defaultBranch = "main";

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
    };

    # --------------------------------------------------------------------------
    # Git LFS
    # --------------------------------------------------------------------------
    lfs.enable = true;

    # --------------------------------------------------------------------------
    # Delta - Better diff viewer
    # --------------------------------------------------------------------------
    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "Dracula";
      };
    };

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
      "*.swp"
      "*.swo"
      "*~"
    ];

    # --------------------------------------------------------------------------
    # Aliases
    # --------------------------------------------------------------------------
    aliases = {
      # Undo
      unstage = "reset HEAD --";
      undo = "reset --soft HEAD~1";

      # Show last commit
      last = "log -1 HEAD --stat";

      # List contributors
      contributors = "shortlog -sn";
    };
  };
}
