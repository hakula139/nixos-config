# ==============================================================================
# PostToolUse Hooks
# ==============================================================================

{
  pkgs,
  lib,
  assistant,
  enableDevToolchains,
  mkHookScript,
  proseDoctrine,
  repo,
  timeouts,
}:

let
  # An empty tool path keeps that package out of a non-dev host's closure.
  whenDev = pkg: if enableDevToolchains then lib.getExe pkg else "";
  whenDevPath = path: if enableDevToolchains then "${path}" else "";

  # ----------------------------------------------------------------------------
  # Formatter configuration
  # ----------------------------------------------------------------------------
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

  proseGatePrompt = pkgs.writeText "prose-tics.md" (
    builtins.replaceStrings [ "@doctrine@" ] [ proseDoctrine ] (
      builtins.readFile ./prose-gate/prose-tics.md
    )
  );
in
{
  autoFormat = mkHookScript {
    slug = "auto-format";
    script = ./auto-format/auto-format.nu;
    writer = pkgs.writers.writeNu;
    substitutions = {
      "@nixfmt@" = lib.getExe pkgs.nixfmt;
      "@nuCheck@" = "${pkgs.nu-check}";
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

  proseGate = mkHookScript {
    slug = "prose-gate";
    script = ./prose-gate/prose-gate.nu;
    writer = pkgs.writers.writeNu;
    substitutions = {
      "@timeout@" = "${pkgs.coreutils}/bin/timeout";
      "@promptFile@" = "${proseGatePrompt}";
      "@candidates@" = "${pkgs.prose-candidates}";
      "@judgeTimeout@" = toString timeouts.modelCall;
    };
  };

  wakatime = mkHookScript {
    slug = "wakatime-heartbeat";
    script = ./wakatime/wakatime.nu;
    writer = pkgs.writers.writeNu;
    substitutions = {
      "@pluginName@" = "${assistant}-hook/1.0";
      "@timeout@" = "${pkgs.coreutils}/bin/timeout";
      "@toolTimeout@" = toString timeouts.tool;
    };
  };
}
