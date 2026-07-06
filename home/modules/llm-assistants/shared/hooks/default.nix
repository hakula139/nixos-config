# ==============================================================================
# Shared Hook Scripts
# ==============================================================================

{
  pkgs,
  ...
}:

let
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

  # Generated (not a static .dprint.json) so the Wasm plugin store paths pin
  # into the closure. emphasis/strong kinds match markdownlint MD049/MD050.
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
  dprintConfig = (pkgs.formats.json { }).generate "dprint.json" {
    markdown = {
      emphasisKind = "underscores";
      strongKind = "asterisks";
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
      substitutions."@dprintConfig@" = "${dprintConfig}";
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
