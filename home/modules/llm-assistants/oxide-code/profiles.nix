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

  # ------------------------------------------------------------------------------------------------
  # Profile assembly
  # ------------------------------------------------------------------------------------------------
  mkProfile =
    _: profile:
    if profile.provider == null then
      { }
    else
      let
        provider = profileDefinitions.providers.${profile.provider};
      in
      {
        baseUrl = provider.apiUrls.anthropic-messages;
        tokenEnv = "ANTHROPIC_AUTH_TOKEN";
        tokenSecret = provider.tokenSecretFor "claude-code";
        extraHeaders = provider.extraHeaders or { };
      }
      // lib.optionalAttrs (profile.provider == "corp-gateway") {
        extraEnv = {
          CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
          # The gateway mistranslates `output_config.format` on session-title requests.
          CLAUDE_CODE_DISABLE_STRUCTURED_OUTPUTS = "1";
        };
        extraSecretEnv.OX_EXTRA_CA_CERTS = provider.caSecret;
      };

  # ------------------------------------------------------------------------------------------------
  # Profile definitions
  # ------------------------------------------------------------------------------------------------
  # oxide-code speaks only the Anthropic Messages wire and accepts only Claude 5.5 model ids.
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
      tokenEnv = "CLAUDE_CODE_OAUTH_TOKEN";
      tokenSecret = "llm-assistants/claude-oauth-token";
    };
  };

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
      customHeaders = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (header: value: "${header}: ${value}") (profile.extraHeaders or { })
      );

      tokenLines =
        if profile ? tokenSecret then
          [
            readSecretFn
            ''${profile.tokenEnv}="$(__read_secret ${esc (secretPath profile.tokenSecret)})"''
            "export ${profile.tokenEnv}"
          ]
        else
          [ "# subscription mode: auth via the Claude Code login" ];

      envLines =
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
  # Clear inherited credentials so none can bypass the active profile.
  profileEnvVars = lib.unique (
    lib.naturalSort [
      "ANTHROPIC_API_KEY"
      "ANTHROPIC_AUTH_TOKEN"
      "ANTHROPIC_BASE_URL"
      "ANTHROPIC_CUSTOM_HEADERS"
      "CLAUDE_CODE_OAUTH_TOKEN"
    ]
    ++ lib.concatMap (
      profile:
      builtins.attrNames (profile.extraEnv or { }) ++ builtins.attrNames (profile.extraSecretEnv or { })
    ) (builtins.attrValues profiles)
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
    defaultProfile = "official";
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
        message = "hakula.oxide-code.auth.defaultProfile requires its profile to be enabled";
      }
    ];

    # ----------------------------------------------------------------------------------------------
    # Secrets
    # ----------------------------------------------------------------------------------------------
    hakula.secrets.required = lib.genAttrs (lib.unique (
      lib.concatMap (
        profile:
        lib.optional (profile ? tokenSecret) profile.tokenSecret
        ++ builtins.attrValues (profile.extraSecretEnv or { })
      ) (builtins.attrValues profiles)
    )) (_: { });

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

  settings.client =
    let
      inherit (enabledProfiles.official.roles) default;
    in
    {
      model = default.modelId;
      inherit (default) effort;
      compaction.auto_threshold_tokens = default.model.autoCompactTokens;
    };
}
