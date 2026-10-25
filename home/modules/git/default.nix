# ==================================================================================================
# Git Configuration
# ==================================================================================================

{
  pkgs,
  lib,
  repoLib,
  secretPath,
  enableDevToolchains ? false,
  ...
}:

let
  esc = lib.escapeShellArg;

  ghPatFile = secretPath "github/pat";

  # Skip the `gh auth` commands that edit stored logins, since they refuse to run with GH_TOKEN set.
  ghBin = repoLib.wrapPackage {
    inherit pkgs;
    pkg = pkgs.gh;
    wrapArgs = [
      "--run"
      ''
        if [[ -z "''${GH_TOKEN:-}" && -z "''${GITHUB_TOKEN:-}" && -s ${esc ghPatFile} ]] \
          && ! [[ "''${1:-}" == auth && "''${2:-}" =~ ^(login|logout|refresh|switch)$ ]]; then
          export GH_TOKEN="$(<${esc ghPatFile})"
        fi
      ''
    ];
  };
in
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
        # Force-moves every branch in the rebased range that no worktree has checked out, silently
        # rewriting other agents' branches in a shared ref store. Pass --update-refs to opt in.
        updateRefs = false;
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
      ".AppleDouble"
      ".DS_Store"
      ".LSOverride"
      "._*"

      # Editor swap / backup files
      "*.swo"
      "*.swp"
      "*~"

      # Dependencies
      ".pnpm-store/"
      "node_modules/"

      # Nix
      ".direnv/"

      # Assistant local state
      "**/.agents/plans/"
      "**/.claude/agent-memory-local"
      "**/.claude/plans"
      "**/.claude/settings.local.json"
      "**/.claude/worktrees/"
      "**/.cursor/plans"
    ];
  };

  # ------------------------------------------------------------------------------------------------
  # GitHub CLI
  # ------------------------------------------------------------------------------------------------
  programs.gh = {
    enable = true;
    package = lib.mkIf enableDevToolchains ghBin;
    settings = {
      git_protocol = "ssh";
    };
  };

  hakula.secrets.required = lib.mkIf enableDevToolchains { "github/pat" = { }; };

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
