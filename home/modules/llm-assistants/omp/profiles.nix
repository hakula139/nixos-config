# ==================================================================================================
# OMP Auth Profiles
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  profileDefinitions,
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

  # ------------------------------------------------------------------------------------------------
  # Profile assembly
  # ------------------------------------------------------------------------------------------------
  mkProfile =
    _:
    {
      roles,
      workloads,
      ...
    }:
    let
      modelRef =
        workload:
        let
          provider = if workload.channel == null then "openai-codex" else workload.source;
        in
        "${provider}/${workload.modelId}";

      mkRole = workload: "${modelRef workload}:${workload.effort}";
    in
    {
      modelRoles = lib.mapAttrs (_: mkRole) workloads // {
        default = mkRole roles.default;
        plan = "@flagship";
        task = "@standard";
        slow = "@flagship";
        smol = "@mini";
        tiny = "@mini";
        advisor = "@tiny";
      };

      compaction = {
        enabled = true;
        modelThresholds = lib.listToAttrs (
          map (workload: lib.nameValuePair (modelRef workload) workload.model.autoCompactTokens) (
            builtins.attrValues workloads
          )
        );
      };
    };

  # ------------------------------------------------------------------------------------------------
  # Profile definitions
  # ------------------------------------------------------------------------------------------------
  enabledProfiles = profileDefinitions.mkProfiles {
    inherit (cfg) enableCorpGateway;
    nativeFamily = "gpt";
    hybridBase = "corp-gateway-anthropic";

    providers = [ "corp-gateway" ];
    channels = [
      "anthropic"
      "openai"
      "google"
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

  # ------------------------------------------------------------------------------------------------
  # Profile switcher
  # ------------------------------------------------------------------------------------------------
  switch = mkProfileSwitch {
    inherit stateDir;
    inherit (cfg) defaultProfile;
    name = "omp-switch";
    assistant = "OMP";
    profilesDir = "${stateDir}/profiles";
    extension = "config.yml";
    configFile = "${configDir}/config.yml";
    resetKeys = [
      "modelRoles"
      "compaction.modelThresholds"
    ];
  };
in
{
  # ------------------------------------------------------------------------------------------------
  # Module options
  # ------------------------------------------------------------------------------------------------
  options = profileDefinitions.mkOptions {
    defaultProfile = if cfg.enableCorpGateway then "corp-gateway-anthropic" else "official";
    enableCorpGateway = config.hakula.llm-assistants.auth.enableCorpGateway;
  };

  # ------------------------------------------------------------------------------------------------
  # Module config
  # ------------------------------------------------------------------------------------------------
  config = {
    # ----------------------------------------------------------------------------------------------
    # Assertions
    # ----------------------------------------------------------------------------------------------
    assertions = [
      {
        assertion = builtins.hasAttr cfg.defaultProfile profiles;
        message = "hakula.omp.auth.defaultProfile requires its profile to be enabled";
      }
    ];

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = lib.mkIf cfg.enableCorpGateway {
      ${corpGateway.tokenSecretFor "omp"} = { };
      ${corpGateway.caSecret} = { };
    };

    # ----------------------------------------------------------------------------------------------
    # Packages
    # ----------------------------------------------------------------------------------------------
    home.packages = [ switch ];

    # ----------------------------------------------------------------------------------------------
    # Profile files
    # ----------------------------------------------------------------------------------------------
    home.file = lib.mapAttrs' (name: settings: {
      name = "${stateDir}/profiles/${name}.config.yml";
      value.source = yaml.generate "omp-profile-${name}.yml" settings;
    }) profiles;

    # ----------------------------------------------------------------------------------------------
    # Activation
    # ----------------------------------------------------------------------------------------------
    # OMP reloads its static model registry only when models.yml's stat mtime changes, and a
    # home-manager store symlink keeps the store's epoch mtime forever, so catalog updates never
    # reach long-running sessions. Install a regular file so activation bumps the mtime.
    home.activation.ompModelsYaml = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run install -m 0600 ${modelsYaml} ${configDir}/models.yml
    '';

    # Keep config.yml writable for profile switching and OMP settings updates.
    home.activation.ompAuthProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe switch} --initialize
    '';
  };

  # ------------------------------------------------------------------------------------------------
  # Exports
  # ------------------------------------------------------------------------------------------------
  envVars = lib.optionalAttrs cfg.enableCorpGateway {
    NODE_EXTRA_CA_CERTS = caFile;
  };
}
