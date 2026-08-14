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
  # ----------------------------------------------------------------------------
  # Hook timeouts
  # ----------------------------------------------------------------------------
  timeouts = rec {
    judge = 30;
    tool = 10;
    # This judge reads a metric report on top of the text: sampled 17-74s. A
    # timed-out leg drops its verdict and looks exactly like a clean pass, so
    # the ceiling sits well clear of the observed tail.
    zhJudge = 120;
    postEdit = judge + zhJudge + 3 * tool;
  };

  # ----------------------------------------------------------------------------
  # Script generation
  # ----------------------------------------------------------------------------
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
  # ----------------------------------------------------------------------------
  # Chinese fingerprint classifier
  # ----------------------------------------------------------------------------
  # Nearest-centroid over five jieba-derived ratios, one classifier per
  # assistant. Fitted on the training half of a labelled corpus (hakula.xyz-kiln
  # prose for human, session transcripts for each assistant's own Chinese) and
  # scored on the disjoint other half, over the paragraphs long enough to
  # measure: claude-code 82% recall at 10% false positives, codex 92% at 3%.
  #
  # `link` counts colons and semicolons per clause. The textbook markers of
  # 欧化中文 run backwards here, so the punctuation hierarchy is what actually
  # carries over from English.
  #
  # The judge prompt is English apart from the symptom names and examples: an
  # all-Chinese prompt doubles as the judge's model of normal Chinese, and it
  # scored 0.37 colons-and-semicolons per clause in its own prescriptions
  # against 0.13 for the English scaffolding.
  zhFingerprintEnv = pkgs.python3.withPackages (ps: [ ps.jieba ]);
  zhFingerprint = pkgs.writeShellScript "zh-fingerprint" ''
    exec ${zhFingerprintEnv}/bin/python3 ${pkgs.copyPathToStore ./scripts/zh-fingerprint.py} "$@"
  '';

  zhFingerprintModels = [
    "claude-code"
    "codex"
  ];
in
{
  inherit timeouts;

  autoFormat = mkHookScript {
    slug = "auto-format";
    script = ./scripts/auto-format.sh;
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

  completenessPrompt = builtins.readFile ./prompts/completeness.md;

  proseGate = mkHookScript {
    slug = "prose-gate";
    script = ./scripts/prose-gate.sh;
    substitutions = {
      "@promptFile@" = "${./prompts/prose-tics.md}";
      "@judgeTimeout@" = toString timeouts.judge;
    };
  };

  wakatime = mkHookScript {
    slug = "wakatime-heartbeat";
    script = ./scripts/wakatime.sh;
    substitutions = {
      "@pluginName@" = "${assistant}-hook/1.0";
      "@timeout@" = "${pkgs.coreutils}/bin/timeout";
      "@toolTimeout@" = toString timeouts.tool;
    };
  };

  # An empty classifier path disables the gate on assistants it was never fitted
  # against, the same way an empty tool path disables a formatter above.
  zhProseGate = mkHookScript {
    slug = "zh-prose-gate";
    script = ./scripts/zh-prose-gate.sh;
    substitutions = {
      "@fingerprint@" = lib.optionalString (builtins.elem assistant zhFingerprintModels) "${
        zhFingerprint
      }";
      "@judgeTimeout@" = toString timeouts.zhJudge;
      "@modelId@" = assistant;
      "@promptFile@" = "${./prompts/zh-prose-tics.md}";
    };
  };
}
