# ==============================================================================
# Codex Auth Profiles
# ==============================================================================

{
  config,
  pkgs,
  lib,
  configDir,
  corpHosts,
  hostType,
  mkProfileSwitch,
  modelCatalog,
  secretPath,
  enabledAgents,
  sharedAgents,
}:

let
  cfg = config.hakula.codex.auth;
  toml = pkgs.formats.toml { };
  stateDir = "${config.xdg.stateHome}/codex";
  tokenFile = secretPath "llm-assistants/bifrost-api-key";
  caFile = secretPath "llm-assistants/corp-cachain.crt";

  # ----------------------------------------------------------------------------
  # Gateway models
  # ----------------------------------------------------------------------------
  # The gateway's /models response is not a Codex model catalog.
  corpModels =
    pkgs.runCommand "codex-corp-models.json"
      {
        nativeBuildInputs = [
          pkgs.codex
          pkgs.jq
        ];
      }
      ''
        codex debug models --bundled | jq -e '
          .models |= map(
            select(.supported_in_api)
            | .slug |= "openai/" + .
            | if .upgrade then .upgrade.model |= "openai/" + . else . end
          )
          | select(.models != [])
        ' > "$out"
      '';

  # ----------------------------------------------------------------------------
  # Model roles
  # ----------------------------------------------------------------------------
  gptModels = modelCatalog.defaults.gpt;
  defaultModel = modelCatalog.models.${gptModels.flagship};

  mkAgents =
    models:
    (import ./agents.nix {
      inherit
        pkgs
        lib
        models
        enabledAgents
        sharedAgents
        ;
    }).settings;

  # ----------------------------------------------------------------------------
  # Profile definitions
  # ----------------------------------------------------------------------------
  profiles = {
    official = {
      model = gptModels.flagship;
      model_provider = "openai";
      model_auto_compact_token_limit = defaultModel.autoCompactTokens;
      agents = mkAgents gptModels;
    };

    corp-gateway = {
      model = defaultModel.gatewayId.openai;
      model_provider = "corp-gateway";
      model_catalog_json = toString corpModels;
      model_auto_compact_token_limit = defaultModel.autoCompactTokens;
      agents = mkAgents (lib.mapAttrs (_: id: modelCatalog.models.${id}.gatewayId.openai) gptModels);
    };
  };

  enabledProfiles = lib.filterAttrs (
    name: _: name != "corp-gateway" || cfg.enableCorpGateway
  ) profiles;

  # ----------------------------------------------------------------------------
  # Profile switcher
  # ----------------------------------------------------------------------------
  switch = mkProfileSwitch {
    inherit stateDir;
    inherit (cfg) defaultProfile;
    name = "codex-switch";
    assistant = "Codex";
    profilesDir = "${stateDir}/profiles";
    extension = "config.toml";
    configFile = "${configDir}/config.toml";
    # Preserve user-defined agents while removing disabled managed roles.
    resetKeys = [
      "model_catalog_json"
    ]
    ++ map (name: "agents.${name}") (builtins.attrNames sharedAgents);
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options = {
    defaultProfile = lib.mkOption {
      type = lib.types.enum [
        "official"
        "corp-gateway"
      ];
      default = "official";
      description = "Fallback authentication profile when no installed profile is active";
    };

    enableCorpGateway = lib.mkOption {
      type = lib.types.bool;
      default = hostType == "work";
      description = "Include the corporate gateway profile and provision its credentials";
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = {
    assertions = [
      {
        assertion = builtins.hasAttr cfg.defaultProfile enabledProfiles;
        message = "hakula.codex.auth.defaultProfile requires its profile to be enabled";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    hakula.secrets.required = lib.optionalAttrs cfg.enableCorpGateway {
      "llm-assistants/bifrost-api-key" = { };
      "llm-assistants/corp-cachain.crt" = { };
    };

    # --------------------------------------------------------------------------
    # Packages
    # --------------------------------------------------------------------------
    home.packages = [ switch ];

    # --------------------------------------------------------------------------
    # Profile files
    # --------------------------------------------------------------------------
    home.file = lib.mapAttrs' (name: settings: {
      name = "${stateDir}/profiles/${name}.config.toml";
      value.source = toml.generate "codex-profile-${name}.toml" settings;
    }) enabledProfiles;

    # --------------------------------------------------------------------------
    # Activation
    # --------------------------------------------------------------------------
    home.activation.codexAuthProfile =
      lib.hm.dag.entryAfter
        [
          "codexMutableConfig"
          "linkGeneration"
        ]
        ''
          ${switch}/bin/codex-switch --initialize
        '';
  };

  # ----------------------------------------------------------------------------
  # Exports
  # ----------------------------------------------------------------------------
  inherit stateDir;

  settings = lib.optionalAttrs cfg.enableCorpGateway {
    model_providers.corp-gateway = {
      name = "Corporate gateway";
      base_url = "${corpHosts.llmGatewayUrl}/v1";
      wire_api = "responses";

      auth = {
        command = "${pkgs.coreutils}/bin/cat";
        args = [ tokenFile ];
      };
    };
  };

  wrapArgs = lib.optionals cfg.enableCorpGateway [
    "--set"
    "CODEX_CA_CERTIFICATE"
    caFile
  ];
}
