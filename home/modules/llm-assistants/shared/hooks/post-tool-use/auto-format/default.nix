# ==============================================================================
# Auto-format Hook
# ==============================================================================

{
  pkgs,
  lib,
  enableDevToolchains,
  mkNuHook,
  repo,
}:

let
  # An empty tool path keeps that package out of a non-dev host's closure.
  whenDev = pkg: if enableDevToolchains then lib.getExe pkg else "";
  whenDevPath = path: if enableDevToolchains then "${path}" else "";

  prettierConfig = builtins.fromJSON (
    builtins.readFile (lib.path.append repo.root ".prettierrc.json")
  );
  ruffConfig = builtins.fromTOML (builtins.readFile (lib.path.append repo.root "ruff.toml"));

  preferredQuoteStyle = single: if single then "preferSingle" else "preferDouble";

  dprintPlugins = with pkgs.dprint-plugins; [
    dprint-plugin-json
    dprint-plugin-markdown
    dprint-plugin-ruff
    dprint-plugin-toml
    dprint-plugin-typescript
    g-plane-malva
    g-plane-markup_fmt
    g-plane-pretty_yaml
  ];

  dprintConfig = (pkgs.formats.json { }).generate "dprint.json" {
    json.lineWidth = prettierConfig.printWidth;
    malva = {
      inherit (prettierConfig) printWidth;
      quotes = preferredQuoteStyle prettierConfig.singleQuote;
    };
    markdown = {
      emphasisKind = "underscores";
      strongKind = "asterisks";
    };
    markup.printWidth = prettierConfig.printWidth;
    ruff = {
      indentStyle = ruffConfig.format.indent-style;
      lineEnding = ruffConfig.format.line-ending;
      lineLength = ruffConfig.line-length;
      quoteStyle = ruffConfig.format.quote-style;
      skipMagicTrailingComma = ruffConfig.format.skip-magic-trailing-comma;
    };
    toml.lineWidth = 80;
    typescript = {
      inherit (prettierConfig) quoteProps;
      "jsx.quoteStyle" = preferredQuoteStyle prettierConfig.jsxSingleQuote;
      lineWidth = prettierConfig.printWidth;
      quoteStyle = preferredQuoteStyle prettierConfig.singleQuote;
    };
    yaml = {
      inherit (prettierConfig) printWidth;
      quotes = preferredQuoteStyle prettierConfig.singleQuote;
    };
    plugins = map (p: "${p}/plugin.wasm") dprintPlugins;
  };
in
mkNuHook {
  slug = "auto-format";
  script = ./auto-format.nu;
  config = {
    cspell = whenDev pkgs.cspell;
    dprint = whenDev pkgs.dprint;
    dprintConfig = whenDevPath dprintConfig;
    markdownlint = whenDev pkgs.markdownlint-cli2;
    nixfmt = lib.getExe pkgs.nixfmt;
    nuCheck = "${pkgs.nu-check}";
    prettier = whenDev pkgs.unstable.prettier;
    ruff = whenDev pkgs.ruff;
    shellcheck = lib.getExe pkgs.shellcheck;
    shfmt = lib.getExe pkgs.shfmt;
    taplo = whenDev pkgs.taplo;
  };
}
