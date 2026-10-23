# ==================================================================================================
# oxide-code Auth Profiles
# ==================================================================================================

{
  config,
  pkgs,
  lib,
  profileDefinitions,
  anthropicProfiles,
  mkProfileSwitch,
}:

let
  cfg = config.hakula.oxide-code.auth;
  stateDir = "${config.xdg.stateHome}/oxide-code";

  # ------------------------------------------------------------------------------------------------
  # Profile assembly
  # ------------------------------------------------------------------------------------------------
  mkProfile =
    _:
    anthropicProfiles.mkProfileAuth {
      client = "oxide-code";
      caEnvVar = "OX_EXTRA_CA_CERTS";
    };

  # ------------------------------------------------------------------------------------------------
  # Profile definitions
  # ------------------------------------------------------------------------------------------------
  # oxide-code speaks only the Anthropic Messages API and serves only Claude models.
  profiles = lib.mapAttrs mkProfile (
    profileDefinitions.mkProfiles {
      inherit (cfg) enableCorpGateway;
      nativeFamily = "claude";

      providers = [
        "corp-gateway"
        "ikuncode"
        "yescode"
      ];

      channels = [ "anthropic" ];
    }
  );

  # ------------------------------------------------------------------------------------------------
  # Profile scripts
  # ------------------------------------------------------------------------------------------------
  mkProfileScript =
    name: profile:
    pkgs.writeShellScript "ox-profile-${name}" (
      lib.concatStringsSep "\n" (anthropicProfiles.mkEnvLines { label = "ox"; } profile)
    );

  # ------------------------------------------------------------------------------------------------
  # Profile loader
  # ------------------------------------------------------------------------------------------------
  profileEnvVars = anthropicProfiles.mkProfileEnvVars {
    extraKnownEnvVars = [
      "NODE_EXTRA_CA_CERTS"
      "OX_EXTRA_CA_CERTS"
    ];
  } profiles;

  profileLoader = pkgs.replaceVars ./scripts/profile-loader.sh {
    inherit stateDir;
    profileEnvVars = toString profileEnvVars;
  };

  # ------------------------------------------------------------------------------------------------
  # Profile switcher
  # ------------------------------------------------------------------------------------------------
  switch = mkProfileSwitch {
    inherit stateDir;
    inherit (cfg) defaultProfile;
    name = "ox-switch";
    assistant = "oxide-code";
    extension = "env.sh";
    profiles = lib.mapAttrs mkProfileScript profiles;
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
    assertions = [ switch.assertion ];

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = anthropicProfiles.mkRequiredSecrets profiles;

    # ----------------------------------------------------------------------------------------------
    # Packages
    # ----------------------------------------------------------------------------------------------
    home.packages = [ switch.package ];

    # ----------------------------------------------------------------------------------------------
    # Profile files
    # ----------------------------------------------------------------------------------------------
    home.file = switch.files;

    # ----------------------------------------------------------------------------------------------
    # Activation
    # ----------------------------------------------------------------------------------------------
    home.activation.oxideCodeProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe switch.package} --initialize
    '';
  };

  # ------------------------------------------------------------------------------------------------
  # Exports
  # ------------------------------------------------------------------------------------------------
  wrapArgs = [
    "--run"
    "source ${profileLoader}"
  ];
}
