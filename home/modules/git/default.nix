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

  # GH_TOKEN overrides stored logins, so export the PAT only when none is readable. `gh auth login`
  # refuses to run while GH_TOKEN is set.
  ghBin = repoLib.wrapPackage {
    inherit pkgs;
    pkg = pkgs.gh;
    wrapArgs = [
      "--run"
      ''
        if [[ -z "''${GH_TOKEN:-}" && -z "''${GITHUB_TOKEN:-}" && -s ${esc ghPatFile} ]] \
          && [[ "''${1:-}" != auth || "''${2:-}" != login ]] \
          && ! ${lib.getExe pkgs.gh} auth token --hostname github.com >/dev/null 2>&1; then
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
