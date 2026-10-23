# ==================================================================================================
# oxide-code Auth Profiles
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
  cfg = config.hakula.oxide-code.auth;
  stateDir = "${config.xdg.stateHome}/oxide-code";

  authEnvByType = {
    oauth-token = "CLAUDE_CODE_OAUTH_TOKEN";
    api-key = "ANTHROPIC_AUTH_TOKEN";
  };

  # ------------------------------------------------------------------------------------------------
  # Profile assembly
  # ------------------------------------------------------------------------------------------------
  mkProfile =
    _: profile:
    if profile.provider == null then
      { type = "subscription"; }
    else
      let
        provider = profileDefinitions.providers.${profile.provider};
      in
      {
        type = "api-key";
        baseUrl = provider.apiUrls.anthropic-messages;
        tokenSecret = provider.tokenSecretFor "oxide-code";
        extraHeaders = provider.extraHeaders or { };
      }
      // lib.optionalAttrs (profile.provider == "corp-gateway") {
        extraEnv.CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
        extraSecretEnv.OX_EXTRA_CA_CERTS = provider.caSecret;
      };

  # ------------------------------------------------------------------------------------------------
  # Profile definitions
  # ------------------------------------------------------------------------------------------------
  # oxide-code speaks only the Anthropic Messages API and serves only Claude models.
  enabledProfiles = profileDefinitions.mkProfiles {
    inherit (cfg) enableCorpGateway;
    nativeFamily = "claude";

    providers = [
      "corp-gateway"
      "ikuncode"
      "yescode"
    ];

    channels = [ "anthropic" ];
  };

  profiles = lib.mapAttrs mkProfile enabledProfiles // {
    official-token = {
      type = "oauth-token";
      tokenSecret = "llm-assistants/claude-oauth-token";
    };
  };

  # ------------------------------------------------------------------------------------------------
  # Profile authentication
  # ------------------------------------------------------------------------------------------------
  requiredSecretNames = lib.unique (
    lib.concatMap (
      profile:
      lib.optional (profile ? tokenSecret) profile.tokenSecret
      ++ builtins.attrValues (profile.extraSecretEnv or { })
    ) (builtins.attrValues profiles)
  );

  requiredSecrets = lib.genAttrs requiredSecretNames (_: { });

  # ------------------------------------------------------------------------------------------------
  # Profile scripts
  # ------------------------------------------------------------------------------------------------
  readSecretFn = ''
    __read_secret() {
      if [[ ! -s "$1" ]]; then
        echo "ox: secret file missing or empty: $1" >&2
        return 1
      fi
      cat "$1"
    }
  '';

  mkProfileScript =
    name: profile:
    let
      esc = lib.escapeShellArg;

      tokenLines =
        if profile.type == "subscription" then
          [ "# subscription mode: auth via the oxide-code or Claude Code login" ]
        else
          let
            sf = esc (secretPath profile.tokenSecret);
            envVar = authEnvByType.${profile.type};
          in
          [
            readSecretFn
            ''${envVar}="$(__read_secret ${sf})"''
            "export ${envVar}"
          ];

      envLines =
        let
          customHeaders = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (header: value: "${header}: ${value}") (profile.extraHeaders or { })
          );
        in
        lib.optional (profile ? baseUrl) "export ANTHROPIC_BASE_URL=${esc profile.baseUrl}"
        ++ lib.optional (customHeaders != "") "export ANTHROPIC_CUSTOM_HEADERS=${esc customHeaders}"
        ++ lib.mapAttrsToList (k: v: "export ${k}=${esc v}") (profile.extraEnv or { })
        ++ lib.mapAttrsToList (k: secretName: "export ${k}=${esc (secretPath secretName)}") (
          profile.extraSecretEnv or { }
        );
    in
    pkgs.writeShellScript "ox-profile-${name}" (lib.concatStringsSep "\n" (tokenLines ++ envLines));

  # ------------------------------------------------------------------------------------------------
  # Profile loader
  # ------------------------------------------------------------------------------------------------
  # Clear inherited credentials, endpoints, and trust bundles so none can bypass the active profile.
  knownProfileEnvVars = builtins.attrValues authEnvByType ++ [
    "ANTHROPIC_API_KEY"
    "ANTHROPIC_BASE_URL"
    "ANTHROPIC_CUSTOM_HEADERS"
    "NODE_EXTRA_CA_CERTS"
    "OX_EXTRA_CA_CERTS"
  ];

  profileEnvVars = lib.naturalSort (
    lib.unique (
      knownProfileEnvVars
      ++ lib.concatMap (
        profile:
        builtins.attrNames (profile.extraEnv or { }) ++ builtins.attrNames (profile.extraSecretEnv or { })
      ) (builtins.attrValues profiles)
    )
  );

  profileLoader = pkgs.replaceVars ./scripts/profile-loader.sh {
    profileEnvVars = toString profileEnvVars;
    inherit stateDir;
  };

  # ------------------------------------------------------------------------------------------------
  # Profile switcher
  # ------------------------------------------------------------------------------------------------
  switch = mkProfileSwitch {
    inherit stateDir;
    inherit (cfg) defaultProfile;
    name = "ox-switch";
    assistant = "oxide-code";
    profilesDir = "${stateDir}/profiles";
    extension = "env.sh";
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
        message = "hakula.oxide-code: auth.defaultProfile '${cfg.defaultProfile}' is not in the enabled profiles";
      }
    ];

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = requiredSecrets;

    # ----------------------------------------------------------------------------------------------
    # Packages
    # ----------------------------------------------------------------------------------------------
    home.packages = [ switch ];

    # ----------------------------------------------------------------------------------------------
    # Profile files
    # ----------------------------------------------------------------------------------------------
    home.file = lib.mapAttrs' (name: profile: {
      name = "${stateDir}/profiles/${name}.env.sh";
      value.source = mkProfileScript name profile;
    }) profiles;

    # ----------------------------------------------------------------------------------------------
    # Activation
    # ----------------------------------------------------------------------------------------------
    home.activation.oxideCodeProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe switch} --initialize
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
