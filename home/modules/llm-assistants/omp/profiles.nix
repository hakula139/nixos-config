# ==============================================================================
# OMP Auth Profiles
# ==============================================================================

{
  config,
  pkgs,
  lib,
  profileDefinitions,
  hostType,
  secretPath,
  mkProfileSwitch,
}:

let
  cfg = config.hakula.omp.auth;
  yaml = pkgs.formats.yaml { };
  configDir = "${config.home.homeDirectory}/.omp/agent";
  stateDir = "${config.xdg.stateHome}/omp";
  modelAliases = profileDefinitions.modelAliases.omp;

  corpGateway = profileDefinitions.providers.corp-gateway;
  caFile = secretPath corpGateway.caSecret;

  # ----------------------------------------------------------------------------
  # Profile assembly
  # ----------------------------------------------------------------------------
  mkProfile =
    name:
    {
      gateway,
      models,
      modelIds,
      ...
    }:
    let
      provider = if gateway == null then "openai-codex" else name;
      model = models.flagship;
    in
    {
      modelRoles =
        lib.mapAttrs' (
          tier: alias:
          lib.nameValuePair alias "${provider}/${modelIds.${tier}}:${models.${tier}.thinking.defaultLevel}"
        ) modelAliases
        // {
          plan = "${provider}/${modelIds.flagship}:high";
          slow = "${provider}/${modelIds.flagship}:max";
        };
      compaction = {
        enabled = true;
        thresholdTokens = model.autoCompactTokens;
      };
    };

  # ----------------------------------------------------------------------------
  # Profile definitions
  # ----------------------------------------------------------------------------
  enabledProfiles = profileDefinitions.mkProfiles {
    inherit (cfg) enableCorpGateway;
    nativeFamily = "gpt";
    providers = [ "corp-gateway" ];
    gateways = [
      "bedrock"
      "openai"
      "local"
    ];
  };
  profiles = lib.mapAttrs mkProfile enabledProfiles;

  models = import ./models.nix {
    inherit
      pkgs
      lib
      profileDefinitions
      secretPath
      ;
    profiles = lib.filterAttrs (_: profile: profile.provider != null) enabledProfiles;
  };

  # ----------------------------------------------------------------------------
  # Profile switcher
  # ----------------------------------------------------------------------------
  switch = mkProfileSwitch {
    inherit stateDir;
    inherit (cfg) defaultProfile;
    name = "omp-switch";
    assistant = "OMP";
    profilesDir = "${stateDir}/profiles";
    extension = "config.yml";
    configFile = "${configDir}/config.yml";
    defaultSettings = import ./settings.nix;
    resetKeys = [
      "modelRoles"
      "ask.notify"
      "completion.notify"
      "error.notify"
    ];
  };
in
{
  # ----------------------------------------------------------------------------
  # Module options
  # ----------------------------------------------------------------------------
  options = profileDefinitions.mkOptions {
    inherit hostType;
    defaultProfile = if cfg.enableCorpGateway then "corp-gateway-openai" else "official";
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
        message = "hakula.omp.auth.defaultProfile requires its profile to be enabled";
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
    home.file = {
      ".omp/agent/models.yml".source = yaml.generate "omp-models.yml" models;
    }
    // lib.mapAttrs' (name: settings: {
      name = "${stateDir}/profiles/${name}.config.yml";
      value.source = yaml.generate "omp-profile-${name}.yml" settings;
    }) profiles;

    # --------------------------------------------------------------------------
    # Activation
    # --------------------------------------------------------------------------
    # Keep config.yml writable for profile switching and OMP settings updates.
    home.activation.ompAuthProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${switch}/bin/omp-switch --initialize
    '';
  };

  # ----------------------------------------------------------------------------
  # Exports
  # ----------------------------------------------------------------------------
  envVars = lib.optionalAttrs cfg.enableCorpGateway {
    NODE_EXTRA_CA_CERTS = caFile;
  };
}
