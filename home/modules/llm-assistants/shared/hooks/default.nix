# ==============================================================================
# Shared Hook Scripts
# ==============================================================================

{
  pkgs,
  lib,
  repo,
  assistant,
  enableDevToolchains ? true,
  ...
}:

let
  mkHookScript =
    {
      slug,
      script,
      substitutions ? { },
    }:
    pkgs.writeShellScript "${assistant}-${slug}" (
      builtins.replaceStrings (builtins.attrNames substitutions) (builtins.attrValues substitutions) (
        builtins.readFile script
      )
    );

  # An empty tool path keeps that package out of a non-dev host's closure.
  whenDev = pkg: if enableDevToolchains then lib.getExe pkg else "";
  whenDevPath = path: if enableDevToolchains then "${path}" else "";

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
  autoFormat = mkHookScript {
    slug = "auto-format";
    script = ./scripts/auto-format.sh;
    substitutions = {
      "@nixfmt@" = lib.getExe pkgs.nixfmt;
      "@shellcheck@" = lib.getExe pkgs.shellcheck;
      "@shfmt@" = lib.getExe pkgs.shfmt;

      "@cspell@" = whenDev pkgs.cspell;
      "@dprint@" = whenDev pkgs.dprint;
      "@dprintConfig@" = whenDevPath dprintConfig;
      "@markdownlint@" = whenDev pkgs.markdownlint-cli2;
      "@prettier@" = whenDev pkgs.unstable.prettier;
      "@ruff@" = whenDev pkgs.ruff;
      "@taplo@" = whenDev pkgs.taplo;
    };
  };

  completenessGate = mkHookScript {
    slug = "completeness-gate";
    script = ./scripts/completeness-gate.sh;
    substitutions = {
      "@promptFile@" = "${./prompts/completeness.md}";
      "@turns@" = "30";
    };
  };

  completenessPrompt = builtins.readFile ./prompts/completeness.md;

  proseGate = mkHookScript {
    slug = "prose-gate";
    script = ./scripts/prose-gate.sh;
    substitutions = {
      "@promptFile@" = "${./prompts/prose-tics.md}";
      "@vale@" = whenDev pkgs.vale;
      "@valeConfig@" = whenDevPath valeConfig;
    };
  };

  wakatime = mkHookScript {
    slug = "wakatime-heartbeat";
    script = ./scripts/wakatime.sh;
    substitutions."@pluginName@" = "${assistant}-hook/1.0";
  };
}
