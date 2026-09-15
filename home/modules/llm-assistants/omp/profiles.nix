# ==============================================================================
# OMP Auth Profiles
# ==============================================================================

{
  config,
  pkgs,
  lib,
  hostType,
  mkProfileSwitch,
  modelCatalog,
}:

let
  cfg = config.hakula.omp.auth;
  yaml = pkgs.formats.yaml { };
  configDir = "${config.home.homeDirectory}/.omp/agent";
  stateDir = "${config.xdg.stateHome}/omp";

  # ----------------------------------------------------------------------------
  # Model roles
  # ----------------------------------------------------------------------------
  claudeModels = modelCatalog.defaults.claude;
  gptModels = modelCatalog.defaults.gpt;
  claudeModel = modelCatalog.models.${claudeModels.flagship};
  gptModel = modelCatalog.models.${gptModels.flagship};

  claudeRoles = provider: models: {
    default = "${provider}/${models.flagship}:${claudeModel.thinking.defaultLevel}";
    plan = "${provider}/${models.flagship}:xhigh";
    slow = "${provider}/${models.flagship}:max";
    smol = "${provider}/${models.mini}:low";
  };

  gptRoles = provider: models: {
    default = "${provider}/${models.flagship}:${gptModel.thinking.defaultLevel}";
    plan = "${provider}/${models.flagship}:high";
    slow = "${provider}/${models.flagship}:max";
    smol = "${provider}/${models.mini}:medium";
  };

  # ----------------------------------------------------------------------------
  # Compaction
  # ----------------------------------------------------------------------------
  mkCompaction = model: {
    enabled = true;
    thresholdTokens = model.autoCompactTokens;
  };

  claudeCompaction = mkCompaction claudeModel;
  gptCompaction = mkCompaction gptModel;

  # ----------------------------------------------------------------------------
  # Profile definitions
  # ----------------------------------------------------------------------------
  profiles = {
    official = {
      modelRoles = gptRoles "openai-codex" gptModels;
      compaction = gptCompaction;
    };
  }
  // lib.optionalAttrs cfg.enableCorpGateway {
    corp-gateway-bedrock = {
      modelRoles = claudeRoles "corp-gateway-bedrock" (
        lib.mapAttrs (_: id: modelCatalog.models.${id}.gatewayId.bedrock) claudeModels
      );
      compaction = claudeCompaction;
    };
    corp-gateway-openai = {
      modelRoles = gptRoles "corp-gateway-openai" (
        lib.mapAttrs (_: id: modelCatalog.models.${id}.gatewayId.openai) gptModels
      );
      compaction = gptCompaction;
    };
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
    resetKeys = [ "modelRoles" ];
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
        "corp-gateway-bedrock"
        "corp-gateway-openai"
      ];
      default = if cfg.enableCorpGateway then "corp-gateway-openai" else "official";
      description = "Fallback authentication profile when no installed profile is active";
    };

    enableCorpGateway = lib.mkOption {
      type = lib.types.bool;
      default = hostType == "work";
      description = "Include corporate gateway profiles and provision their credentials";
    };
  };

  # ----------------------------------------------------------------------------
  # Module config
  # ----------------------------------------------------------------------------
  config = {
    assertions = [
      {
        assertion = builtins.hasAttr cfg.defaultProfile profiles;
        message = "hakula.omp.auth.defaultProfile requires its profile to be enabled";
      }
    ];

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
    # Keep config.yml writable for profile switching and OMP settings updates.
    home.activation.ompAuthProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      ${switch}/bin/omp-switch --initialize
    '';
  };
}
