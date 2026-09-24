# ==============================================================================
# OMP Auth Profiles
# ==============================================================================

{
  config,
  pkgs,
  lib,
  profileDefinitions,
  sharedAgents,
  hostType,
  secretPath,
  mkProfileSwitch,
}:

let
  cfg = config.hakula.omp.auth;
  yaml = pkgs.formats.yaml { };
  configDir = "${config.home.homeDirectory}/.omp/agent";
  stateDir = "${config.xdg.stateHome}/omp";

  corpGateway = profileDefinitions.providers.corp-gateway;
  caFile = secretPath corpGateway.caSecret;

  # ----------------------------------------------------------------------------
  # Profile assembly
  # ----------------------------------------------------------------------------
  mkProfile =
    name:
    {
      gateway,
      roles,
      workloads,
      ...
    }:
    let
      provider = if gateway == null then "openai-codex" else name;
      mkRole = workload: "${provider}/${workload.modelId}:${workload.effort}";
    in
    {
      modelRoles = lib.mapAttrs (_: mkRole) workloads // {
        default = "@standard";
        plan = "@flagship";
        task = "@standard";
        slow = "@flagship";
        smol = "@mini";
        tiny = "@mini";
        advisor = "@tiny";
      };
      compaction = {
        enabled = true;
        thresholdTokens = roles.default.model.autoCompactTokens;
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

  modelsYaml = yaml.generate "omp-models.yml" models;

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
    defaultSettings = import ./settings.nix {
      inherit sharedAgents;
    };
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
    home.file = lib.mapAttrs' (name: settings: {
      name = "${stateDir}/profiles/${name}.config.yml";
      value.source = yaml.generate "omp-profile-${name}.yml" settings;
    }) profiles;

    # --------------------------------------------------------------------------
    # Activation
    # --------------------------------------------------------------------------
    # OMP reloads its static model registry only when models.yml's stat mtime
    # changes, and a home-manager store symlink keeps the store's epoch mtime
    # forever, so catalog updates never reach long-running sessions. Install a
    # regular file so activation bumps the mtime.
    home.activation.ompModelsYaml = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run install -m 0600 ${modelsYaml} ${configDir}/models.yml
    '';

    # Keep config.yml writable for profile switching and OMP settings updates.
    home.activation.ompAuthProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${lib.getExe switch} --initialize
    '';
  };

  # ----------------------------------------------------------------------------
  # Exports
  # ----------------------------------------------------------------------------
  envVars = lib.optionalAttrs cfg.enableCorpGateway {
    NODE_EXTRA_CA_CERTS = caFile;
  };
}
