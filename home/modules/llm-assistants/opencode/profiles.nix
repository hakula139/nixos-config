# ==============================================================================
# OpenCode Auth Profiles
# ==============================================================================

{
  config,
  pkgs,
  lib,
  corpHosts,
  hostType,
  mkProfileSwitch,
  modelCatalog,
  secretPath,
  enabledAgents,
  sharedAgents,
}:

let
  cfg = config.hakula.opencode.auth;
  json = pkgs.formats.json { };
  stateDir = "${config.xdg.stateHome}/opencode";
  tokenFile = secretPath "llm-assistants/bifrost-api-key";
  caFile = secretPath "llm-assistants/corp-cachain.crt";

  # ----------------------------------------------------------------------------
  # Model roles
  # ----------------------------------------------------------------------------
  gptModels = modelCatalog.defaults.gpt;
  gptModelIds = lib.unique (builtins.attrValues gptModels);
  managedAgents = lib.filterAttrs (
    name: agent: lib.elem name enabledAgents && agent ? modelTier
  ) sharedAgents;

  mkModels =
    modelIds: corp:
    lib.listToAttrs (
      map (
        id:
        let
          model = modelCatalog.models.${id};
        in
        {
          name = modelIds.${id};
          value = {
            inherit (model) name reasoning;
            modalities = {
              input = [
                "text"
                "image"
              ];
              output = [ "text" ];
            };
            limit = {
              context = model.contextWindow;
              output = model.maxTokens;
            };
            options = {
              reasoningEffort = model.thinking.defaultLevel;
              textVerbosity = "low";
            };
            variants = lib.genAttrs model.thinking.efforts (effort: {
              reasoningEffort = effort;
            });
          }
          // lib.optionalAttrs corp {
            cost = {
              inherit (model.gatewayCost.openai) input output;
              cache_read = model.gatewayCost.openai.cacheRead;
              cache_write = model.gatewayCost.openai.cacheWrite;
            };
          };
        }
      ) gptModelIds
    );

  mkProfile = provider: modelIds: {
    model = "${provider}/${modelIds.${gptModels.flagship}}";
    small_model = "${provider}/${modelIds.${gptModels.mini}}";
    agent = lib.mapAttrs (_: agent: {
      model = "${provider}/${modelIds.${gptModels.${agent.modelTier}}}";
    }) managedAgents;
    provider.${provider}.models = mkModels modelIds (provider == "corp-gateway");
  };

  # ----------------------------------------------------------------------------
  # Profile definitions
  # ----------------------------------------------------------------------------
  profiles = {
    official = mkProfile "openai" (lib.genAttrs gptModelIds (id: id));
  }
  // lib.optionalAttrs cfg.enableCorpGateway {
    corp-gateway =
      lib.recursiveUpdate
        (mkProfile "corp-gateway" (
          lib.genAttrs gptModelIds (id: modelCatalog.models.${id}.gatewayId.openai)
        ))
        {
          provider.corp-gateway = {
            name = "Corporate gateway";
            npm = "@ai-sdk/openai";
            options = {
              baseURL = "${corpHosts.llmGatewayUrl}/v1";
              apiKey = "{file:${tokenFile}}";
            };
          };
        };
  };

  # ----------------------------------------------------------------------------
  # Profile switcher
  # ----------------------------------------------------------------------------
  switch = mkProfileSwitch {
    inherit stateDir;
    inherit (cfg) defaultProfile;
    name = "opencode-switch";
    assistant = "OpenCode";
    profilesDir = "${stateDir}/profiles";
    extension = "json";
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
      default = if cfg.enableCorpGateway then "corp-gateway" else "official";
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
        assertion = builtins.hasAttr cfg.defaultProfile profiles;
        message = "hakula.opencode.auth.defaultProfile requires its profile to be enabled";
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
      name = "${stateDir}/profiles/${name}.json";
      value.source = json.generate "opencode-profile-${name}.json" settings;
    }) profiles;

    # --------------------------------------------------------------------------
    # Activation
    # --------------------------------------------------------------------------
    home.activation.opencodeAuthProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${switch}/bin/opencode-switch --initialize
    '';
  };

  # ----------------------------------------------------------------------------
  # Exports
  # ----------------------------------------------------------------------------
  wrapArgs = [
    "--set"
    "OPENCODE_CONFIG"
    "${stateDir}/active-profile"
  ]
  ++ lib.optionals cfg.enableCorpGateway [
    "--set"
    "NODE_EXTRA_CA_CERTS"
    caFile
  ];
}
