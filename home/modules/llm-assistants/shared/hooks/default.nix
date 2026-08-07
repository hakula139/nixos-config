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
  # The prose gate's LLM judge costs ~12.5s per call, and most edits are pure
  # code. vale's per-language parsers strip code and string literals, so a
  # payload yielding no alerts carries no prose or comment worth judging. This
  # rule matches any word, so it is a presence probe rather than a style check.
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
  # `devTools = false` drops ~655 MiB of closure per host: the empty branches
  # never force their packages.
  mkAutoFormatScript =
    {
      name ? "auto-format",
      devTools ? true,
    }:
    let
      devTool = pkg: if devTools then lib.getExe pkg else "";
    in
    mkHookScript {
      inherit name;
      script = ./scripts/auto-format.sh;
      substitutions = {
        "@devTools@" = lib.boolToString devTools;
        "@nixfmt@" = lib.getExe pkgs.nixfmt;
        "@shellcheck@" = lib.getExe pkgs.shellcheck;
        "@shfmt@" = lib.getExe pkgs.shfmt;

        "@cspell@" = devTool pkgs.cspell;
        "@dprint@" = devTool pkgs.dprint;
        "@dprintConfig@" = if devTools then "${dprintConfig}" else "";
        "@harper@" = if devTools then "${lib.getBin pkgs.harper}/bin/harper-cli" else "";
        "@markdownlint@" = devTool pkgs.markdownlint-cli2;
        "@prettier@" = devTool pkgs.unstable.prettier;
        "@ruff@" = devTool pkgs.ruff;
        "@taplo@" = devTool pkgs.taplo;
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

  mkGuardLocalFilesScript =
    {
      name ? "guard-local-files",
    }:
    mkHookScript {
      inherit name;
      script = ./scripts/guard-local-files.sh;
    };

  mkProseGateScript =
    {
      name ? "prose-gate",
      promptFile,
      devTools ? true,
    }:
    mkHookScript {
      inherit name;
      script = ./scripts/prose-gate.sh;
      substitutions = {
        "@promptFile@" = "${promptFile}";
        "@vale@" = if devTools then lib.getExe pkgs.vale else "";
        "@valeConfig@" = if devTools then "${valeConfig}" else "";
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
