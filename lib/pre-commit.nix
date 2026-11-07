# ==================================================================================================
# Pre-commit Checks
# ==================================================================================================

{
  pkgs,
  inputs,
}:

let
  inherit (pkgs) lib;

  json = pkgs.formats.json { };

  dprintConfig = json.generate "dprint.json" {
    markdown = {
      emphasisKind = "underscores";
      strongKind = "asterisks";
    };

    # Language plugins would also rewrite fenced examples inside Markdown.
    plugins = [ "${pkgs.dprint-plugins.dprint-plugin-markdown}/plugin.wasm" ];
  };
in
inputs.git-hooks-nix.lib.${pkgs.stdenv.hostPlatform.system}.run {
  src = inputs.self;
  tools = import "${inputs.git-hooks-nix}/nix/call-tools.nix" pkgs;
  package = pkgs.prek;

  excludes = [
    "(^|/)fixtures/"
  ];

  hooks = {
    check-added-large-files.enable = true;
    check-yaml.enable = true;

    cspell = {
      enable = true;
      args = [
        "--no-progress"
        "--no-must-find-files"
      ];
    };

    deadnix.enable = true;

    doctoc = {
      enable = true;
      description = "Generate the table of contents in Markdown files.";
      entry = lib.getExe pkgs.doctoc;
      args = [
        "--update-only"
        "--notitle"
        "--maxlevel=3"
      ];
      files = "\\.md$";
    };

    dprint = {
      enable = true;
      description = "Format Markdown with dprint.";
      entry = "${lib.getExe pkgs.dprint} fmt";
      # dprint honors ancestor .gitignore files, and this repository ignores `/.claude/worktrees/`,
      # which would skip every file in an agent worktree.
      args = [
        "--config=${dprintConfig}"
        "--allow-no-files"
        "--no-gitignore"
      ];
      files = "\\.md$";
    };

    editorconfig-checker.enable = true;

    end-of-file-fixer = {
      enable = true;
      excludes = [
        "\\.age$"
      ];
    };

    markdownlint = {
      enable = true;
      args = [ "--fix" ];
    };

    nixfmt.enable = true;

    nu-check = {
      enable = true;
      description = "Run nushell's diagnostic check on .nu files.";
      entry = lib.getExe pkgs.nu-check;
      files = "\\.nu$";
    };

    prettier = {
      enable = true;
      # Markdown stays out of Prettier, which drops the blank line before nested items.
      files = "\\.(js|json|jsonc|ts|ya?ml)$";
    };

    ruff.enable = true;
    ruff-format.enable = true;

    shellcheck = {
      enable = true;
      # ShellCheck has no zsh dialect.
      excludes = [ "\\.zsh$" ];
    };

    # `shfmt` reads `.editorconfig` only when the entry passes no formatting flag. Any flag reverts
    # it to tabs and ignores the `binary_next_line` and `switch_case_indent` keys.
    # `simplify` also strips the quotes inside `[[ ]]`.
    shfmt = {
      enable = true;
      settings = {
        language-dialect = null;
        simplify = false;
        indent = null;
        binary-next-line = false;
        case-indent = false;
      };
    };

    statix.enable = true;
    taplo.enable = true;

    trim-trailing-whitespace = {
      enable = true;
      # Preserve Markdown's two-trailing-space hard-break syntax.
      args = [ "--markdown-linebreak-ext=md" ];
      excludes = [
        "\\.age$"
        "\\.patch$"
      ];
    };
  };
}
