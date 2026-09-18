# ==============================================================================
# Codex Model Catalogs
# ==============================================================================

{
  pkgs,
  lib,
}:

profile:

let
  # ----------------------------------------------------------------------------
  # GPT models
  # ----------------------------------------------------------------------------
  gptDefaults = lib.mapAttrs' (
    tier: model: lib.nameValuePair profile.modelIds.${tier} model.thinking.defaultLevel
  ) profile.models;

  # Codex requires its native catalog's capabilities and prompt metadata.
  gpt =
    pkgs.runCommand "codex-corp-models.json"
      {
        nativeBuildInputs = [
          pkgs.codex
          pkgs.jq
        ];
      }
      ''
        codex debug models --bundled \
          | jq -e \
            --argjson defaults ${lib.escapeShellArg (builtins.toJSON gptDefaults)} '
              .models |= map(
                select(.supported_in_api)
                | .slug |= "openai/" + .
                | .default_reasoning_level = ($defaults[.slug] // .default_reasoning_level)
                | if .upgrade then .upgrade.model |= "openai/" + . else . end
              )
              | select(.models != [])
            ' > "$out"
      '';

  # ----------------------------------------------------------------------------
  # Local models
  # ----------------------------------------------------------------------------
  localModelMetadata = {
    models =
      lib.imap0
        (priority: model: {
          inherit priority;
          slug = model.gatewayId.${profile.gateway};
          display_name = model.name;
          description = "${model.name} via the corporate gateway";
          default_reasoning_level = model.thinking.defaultLevel;
          supported_reasoning_levels = map (effort: {
            inherit effort;
            description = "${effort} reasoning effort";
          }) model.thinking.efforts;
          shell_type = "unified_exec";
          visibility = "list";
          supported_in_api = true;
          include_apps_usage_instructions = false;
          supports_reasoning_summary_parameter = false;
          default_reasoning_summary = "none";
          support_verbosity = false;
          truncation_policy = {
            mode = "bytes";
            limit = 10000;
          };
          context_window = model.contextWindow;
          max_context_window = model.contextWindow;
          auto_compact_token_limit = model.autoCompactTokens;
          experimental_supported_tools = [ ];
          input_modalities = model.input;
        })
        (
          lib.unique (
            map (tier: profile.models.${tier}) [
              "flagship"
              "standard"
              "mini"
            ]
          )
        );
  };

  # Read the upstream prompt at build time to avoid import-from-derivation.
  local =
    pkgs.runCommand "codex-corp-local-models.json"
      {
        nativeBuildInputs = [ pkgs.jq ];
        modelMetadata = builtins.toJSON localModelMetadata;
        passAsFile = [ "modelMetadata" ];
      }
      ''
        jq --rawfile instructions \
          ${lib.escapeShellArg "${pkgs.codex.src}/codex-rs/models-manager/prompt.md"} '
            .models |= map(.model_messages = { instructions_template: $instructions })
          ' "$modelMetadataPath" > "$out"
      '';
in
{
  inherit gpt local;
}
.${profile.family}
