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

  # ----------------------------------------------------------------------------
  # Prose detection
  # ----------------------------------------------------------------------------
  # A `\w+` rule under vale's `text` scope matches only what its per-language
  # parser treats as prose, so no alerts means the payload is pure code.
  valeStyles = pkgs.runCommand "vale-prose-styles" { } ''
    mkdir -p $out/Prose
    cat > $out/Prose/HasProse.yml <<'EOF'
    extends: existence
    message: "prose present"
    level: warning
    scope: text
    tokens:
      - '\w+'
    EOF
  '';

  valeConfig = pkgs.writeText "vale.ini" ''
    StylesPath = ${valeStyles}
    MinAlertLevel = warning

    [*]
    BasedOnStyles = Prose
  '';
in
{
  # An empty tool path keeps that package out of a non-dev host's closure.
  mkAutoFormatScript =
    {
      name ? "auto-format",
      enableDevToolchains ? true,
    }:
    let
      whenDev = pkg: if enableDevToolchains then lib.getExe pkg else "";
    in
    mkHookScript {
      inherit name;
      script = ./scripts/auto-format.sh;
      substitutions = {
        "@nixfmt@" = lib.getExe pkgs.nixfmt;
        "@shellcheck@" = lib.getExe pkgs.shellcheck;
        "@shfmt@" = lib.getExe pkgs.shfmt;

        "@cspell@" = whenDev pkgs.cspell;
        "@dprint@" = whenDev pkgs.dprint;
        "@dprintConfig@" = if enableDevToolchains then "${dprintConfig}" else "";
        "@markdownlint@" = whenDev pkgs.markdownlint-cli2;
        "@prettier@" = whenDev pkgs.unstable.prettier;
        "@ruff@" = whenDev pkgs.ruff;
        "@taplo@" = whenDev pkgs.taplo;
      };
    };

  mkCompletenessGateScript =
    {
      name ? "completeness-gate",
      promptFile,
      turns ? 30,
    }:
    mkHookScript {
      inherit name;
      script = ./scripts/completeness-gate.sh;
      substitutions = {
        "@promptFile@" = "${promptFile}";
        "@turns@" = toString turns;
      };
    };

  mkProseGateScript =
    {
      name ? "prose-gate",
      promptFile,
      enableDevToolchains ? true,
    }:
    mkHookScript {
      inherit name;
      script = ./scripts/prose-gate.sh;
      substitutions = {
        "@promptFile@" = "${promptFile}";
        "@vale@" = if enableDevToolchains then lib.getExe pkgs.vale else "";
        "@valeConfig@" = if enableDevToolchains then "${valeConfig}" else "";
      };
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
