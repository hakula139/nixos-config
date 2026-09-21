# ==============================================================================
# Codex Auth Profiles
# ==============================================================================

{
  config,
  pkgs,
  lib,
  profileDefinitions,
  sharedAgents,
  enabledAgents,
  hostType,
  secretPath,
  configDir,
  mkProfileSwitch,
}:

let
  cfg = config.hakula.codex.auth;
  toml = pkgs.formats.toml { };
  stateDir = "${config.xdg.stateHome}/codex";

  corpGateway = profileDefinitions.providers.corp-gateway;
  tokenFile = secretPath corpGateway.tokenSecret;
  caFile = secretPath corpGateway.caSecret;

  mkModelCatalog = import ./models.nix {
    inherit pkgs lib;
  };

  # ----------------------------------------------------------------------------
  # Profile assembly
  # ----------------------------------------------------------------------------
  mkAgents =
    models:
    (import ./agents.nix {
      inherit
        pkgs
        lib
        sharedAgents
        enabledAgents
        models
        ;
    }).settings;

  mkProfile =
    _: profile:
    {
      model = profile.modelIds.flagship;
      model_provider = if profile.gateway == null then "openai" else "corp-gateway";
      model_reasoning_effort = profile.models.flagship.thinking.defaultLevel;
      agents = mkAgents profile.modelIds;
      web_search = if profile.nativeWebSearch then "live" else "disabled";
    }
    // lib.optionalAttrs (profile.gateway != null) {
      model_catalog_json = toString (mkModelCatalog profile);
    }
    // lib.optionalAttrs (profile.family == "gpt") {
      model_auto_compact_token_limit = profile.models.flagship.autoCompactTokens;
    };

  # ----------------------------------------------------------------------------
  # Profile definitions
  # ----------------------------------------------------------------------------
  profiles = lib.mapAttrs mkProfile (
    profileDefinitions.mkProfiles {
      inherit (cfg) enableCorpGateway;
      nativeFamily = "gpt";
      providers = [ "corp-gateway" ];
      gateways = [
        "openai"
        "local"
      ];
    }
  );

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
      "model_auto_compact_token_limit"
      "model_catalog_json"
    ]
    ++ map (name: "agents.${name}") (builtins.attrNames sharedAgents);
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options = profileDefinitions.mkOptions {
    inherit hostType;
    defaultProfile = "official";
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = {
    # --------------------------------------------------------------------------
    # Assertions
    # --------------------------------------------------------------------------
    assertions = [
      {
        assertion = builtins.hasAttr cfg.defaultProfile profiles;
        message = "hakula.codex.auth.defaultProfile requires its profile to be enabled";
      }
    ];

    # --------------------------------------------------------------------------
    # Secrets
    # --------------------------------------------------------------------------
    hakula.secrets.required = lib.mkIf cfg.enableCorpGateway {
      ${corpGateway.tokenSecret} = { };
      ${corpGateway.caSecret} = { };
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
    }) profiles;

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
          ${lib.getExe switch} --initialize
        '';
  };

  # ----------------------------------------------------------------------------
  # Exports
  # ----------------------------------------------------------------------------
  inherit stateDir;

  settings = lib.optionalAttrs cfg.enableCorpGateway {
    model_providers.corp-gateway = {
      name = "Corporate gateway";
      base_url = corpGateway.apiUrls.openai-responses;
      wire_api = "responses";

      auth = {
        command = lib.getExe' pkgs.coreutils "cat";
        args = [ tokenFile ];
      };
    };
  };

  envVars = lib.optionalAttrs cfg.enableCorpGateway {
    CODEX_CA_CERTIFICATE = caFile;
  };
}
