# ==================================================================================================
# Shared Tooling
# ==================================================================================================

{
  pkgs,
}:

let
  inherit (pkgs) lib;

  json = pkgs.formats.json { };

  # ------------------------------------------------------------------------------------------------
  # Nix Development
  # ------------------------------------------------------------------------------------------------
  nix = with pkgs; [
    cachix
    colmena
    deadnix
    nh
    nixd
    nix-tree
    nixfmt
    nom
    nvd
    statix
  ];

  # ------------------------------------------------------------------------------------------------
  # Secrets Management
  # ------------------------------------------------------------------------------------------------
  secrets = with pkgs; [
    age
    agenix
  ];

  # ------------------------------------------------------------------------------------------------
  # Shell Scripting
  # ------------------------------------------------------------------------------------------------
  # Only the dev shell consumes this. Every real host gets nushell from `programs.nushell`, which
  # also writes the config files its LSP needs.
  shell = with pkgs; [
    nushell
    nu-test
  ];

  # ------------------------------------------------------------------------------------------------
  # Formatting
  # ------------------------------------------------------------------------------------------------
  markdownDprintConfig = json.generate "dprint.json" {
    markdown = {
      emphasisKind = "underscores";
      strongKind = "asterisks";
    };

    # Language plugins would also rewrite fenced examples inside Markdown.
    plugins = [ "${pkgs.dprint-plugins.dprint-plugin-markdown}/plugin.wasm" ];
  };

  markdownDprintConfigDir = pkgs.linkFarm "markdown-dprint-config" [
    {
      name = "dprint.json";
      path = markdownDprintConfig;
    }
  ];

  formatterExtensions = [
    ".sh"
    ".nix"
    ".py"
    ".rs"
    ".go"
    ".toml"
    ".css"
    ".scss"
    ".less"
    ".js"
    ".jsx"
    ".mjs"
    ".cjs"
    ".ts"
    ".tsx"
    ".vue"
    ".md"
  ];

  mkFormatFiles =
    {
      enableDevToolchains,
    }:
    let
      # Empty paths keep dev-only tools out of non-dev closures.
      whenDev = pkg: if enableDevToolchains then lib.getExe pkg else "";
      whenDevPath = path: if enableDevToolchains then "${path}" else "";

      configFile = json.generate "format-files.json" {
        cspell = whenDev pkgs.cspell;
        direnv = whenDev pkgs.direnv;
        dprint = whenDev pkgs.dprint;
        dprintConfigDir = whenDevPath markdownDprintConfigDir;
        git = lib.getExe pkgs.git;
        markdownlint = whenDev pkgs.markdownlint-cli2;
        markdownlintConfig = whenDevPath ../.markdownlint.jsonc;
        nixfmt = lib.getExe pkgs.nixfmt;
        nuCheck = "${pkgs.nu-check}";
        prettier = whenDev pkgs.unstable.prettier;
        pyright = whenDev pkgs.pyright;
        ruff = whenDev pkgs.ruff;
        shellcheck = lib.getExe pkgs.shellcheck;
        shfmt = lib.getExe pkgs.shfmt;
        taplo = whenDev pkgs.taplo;
      };
    in
    pkgs.writers.writeNuBin "format-files" {
      makeWrapperArgs = [
        "--prefix"
        "PATH"
        ":"
        (lib.makeBinPath [ pkgs.coreutils ])

        "--add-flag"
        "${configFile}"
      ];
    } (builtins.readFile ./format-files.nu);

  # ------------------------------------------------------------------------------------------------
  # Script Tests
  # ------------------------------------------------------------------------------------------------
  scriptPython = pkgs.python3.withPackages (ps: [ ps.jinja2 ]);
in
{
  inherit
    nix
    secrets
    shell
    markdownDprintConfig
    markdownDprintConfigDir
    formatterExtensions
    mkFormatFiles
    scriptPython
    ;

  all = nix ++ secrets ++ shell;
}
