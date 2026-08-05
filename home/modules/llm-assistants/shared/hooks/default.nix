# ==============================================================================
# Shared Hook Scripts
# ==============================================================================

{
  pkgs,
  lib,
  repo,
  ...
}:

let
  # ----------------------------------------------------------------------------
  # Script generation
  # ----------------------------------------------------------------------------
  mkHookScript =
    {
      name,
      script,
      substitutions ? { },
    }:
    pkgs.writeShellScript name (
      builtins.replaceStrings (builtins.attrNames substitutions) (builtins.attrValues substitutions) (
        builtins.readFile script
      )
    );

  # ----------------------------------------------------------------------------
  # Formatter configuration
  # ----------------------------------------------------------------------------
  dprintPlugins = with pkgs.dprint-plugins; [
    dprint-plugin-markdown
    dprint-plugin-ruff
    dprint-plugin-typescript
    dprint-plugin-json
    dprint-plugin-toml
    g-plane-pretty_yaml
    g-plane-malva
    g-plane-markup_fmt
  ];

  prettierConfig = builtins.fromJSON (
    builtins.readFile (lib.path.append repo.root ".prettierrc.json")
  );
  ruffConfig = builtins.fromTOML (builtins.readFile (lib.path.append repo.root "ruff.toml"));

  preferredQuoteStyle = single: if single then "preferSingle" else "preferDouble";

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
{
  mkAutoFormatScript =
    {
      name ? "auto-format",
    }:
    mkHookScript {
      inherit name;
      script = ./scripts/auto-format.sh;
      substitutions = {
        "@cspell@" = lib.getExe pkgs.cspell;
        "@dprint@" = lib.getExe pkgs.dprint;
        "@dprintConfig@" = "${dprintConfig}";
        "@markdownlint@" = lib.getExe pkgs.markdownlint-cli2;
        "@nixfmt@" = lib.getExe pkgs.nixfmt;
        "@prettier@" = lib.getExe pkgs.unstable.prettier;
        "@ruff@" = lib.getExe pkgs.ruff;
        "@shellcheck@" = lib.getExe pkgs.shellcheck;
        "@shfmt@" = lib.getExe pkgs.shfmt;
        "@taplo@" = lib.getExe pkgs.taplo;
      };
    };

  mkEnforceMcpScript =
    {
      name ? "enforce-mcp",
      hintMode,
    }:
    mkHookScript {
      inherit name;
      script = ./scripts/enforce-mcp.sh;
      substitutions."@hintMode@" = hintMode;
    };

  mkProseGateScript =
    {
      name ? "prose-gate",
      promptFile,
    }:
    mkHookScript {
      inherit name;
      script = ./scripts/prose-gate.sh;
      substitutions."@promptFile@" = "${promptFile}";
    };

  mkWakatimeScript =
    {
      name ? "wakatime-heartbeat",
      pluginName,
    }:
    mkHookScript {
      inherit name;
      script = ./scripts/wakatime.sh;
      substitutions."@pluginName@" = pluginName;
    };
}
