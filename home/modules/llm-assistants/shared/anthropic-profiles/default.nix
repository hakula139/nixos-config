# ==================================================================================================
# Anthropic Environment Profiles
# ==================================================================================================

# Auth profiles for clients configured through Claude Code's environment variables.

{
  lib,
  providers,
  secretPath,
}:

let
  authEnvByType = {
    oauth-token = "CLAUDE_CODE_OAUTH_TOKEN";
    api-key = "ANTHROPIC_AUTH_TOKEN";
  };

  knownEnvVars = builtins.attrValues authEnvByType ++ [
    "ANTHROPIC_API_KEY"
    "ANTHROPIC_BASE_URL"
    "ANTHROPIC_CUSTOM_HEADERS"
  ];
in
{
  # ------------------------------------------------------------------------------------------------
  # Profile authentication
  # ------------------------------------------------------------------------------------------------
  mkProfileAuth =
    {
      client,
      caEnvVar,
    }:
    profile:
    if profile.oauthTokenSecret != null then
      {
        type = "oauth-token";
        tokenSecret = profile.oauthTokenSecret;
      }
    else if profile.provider == null then
      { type = "subscription"; }
    else
      let
        provider = providers.${profile.provider};
      in
      {
        type = "api-key";
        baseUrl = provider.apiUrls.anthropic-messages;
        tokenSecret = provider.tokenSecretFor client;
        extraHeaders = provider.extraHeaders or { };
      }
      // lib.optionalAttrs (profile.provider == "corp-gateway") {
        extraEnv.CLAUDE_CODE_ATTRIBUTION_HEADER = "0";
        extraSecretEnv.${caEnvVar} = provider.caSecret;
      };

  mkRequiredSecrets =
    profiles:
    lib.genAttrs (lib.unique (
      lib.concatMap (
        profile:
        lib.optional ((profile.tokenSecret or null) != null) profile.tokenSecret
        ++ builtins.attrValues (profile.extraSecretEnv or { })
      ) (builtins.attrValues profiles)
    )) (_: { });

  # ------------------------------------------------------------------------------------------------
  # Profile scripts
  # ------------------------------------------------------------------------------------------------
  mkEnvLines =
    {
      label,
      subscriptionNote,
    }:
    profile:
    let
      esc = lib.escapeShellArg;

      tokenLines =
        if profile.type == "subscription" then
          [ "# subscription mode: ${subscriptionNote}" ]
        else
          let
            sf = esc (secretPath profile.tokenSecret);
            envVar = authEnvByType.${profile.type};
          in
          [
            ''
              __read_secret() {
                if [[ ! -s "$1" ]]; then
                  echo "${label}: secret file missing or empty: $1" >&2
                  return 1
                fi
                cat "$1"
              }
            ''
            ''${envVar}="$(__read_secret ${sf})"''
            "export ${envVar}"
          ];

      customHeaders = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: value: "${name}: ${value}") (profile.extraHeaders or { })
      );
    in
    tokenLines
    ++ lib.optional (
      (profile.baseUrl or null) != null
    ) "export ANTHROPIC_BASE_URL=${esc profile.baseUrl}"
    ++ lib.optional (customHeaders != "") "export ANTHROPIC_CUSTOM_HEADERS=${esc customHeaders}"
    ++ lib.mapAttrsToList (k: v: "export ${k}=${esc v}") (profile.extraEnv or { })
    ++ lib.mapAttrsToList (k: secretName: "export ${k}=${esc (secretPath secretName)}") (
      profile.extraSecretEnv or { }
    );

  # ------------------------------------------------------------------------------------------------
  # Profile loader
  # ------------------------------------------------------------------------------------------------
  # The loader clears these before sourcing the active profile, so no inherited credential,
  # endpoint, or trust bundle can bypass it.
  mkProfileEnvVars =
    {
      extraKnownEnvVars ? [ ],
    }:
    profiles:
    lib.unique (
      lib.naturalSort (knownEnvVars ++ extraKnownEnvVars)
      ++ lib.concatMap (
        profile:
        builtins.attrNames (profile.extraEnv or { }) ++ builtins.attrNames (profile.extraSecretEnv or { })
      ) (builtins.attrValues profiles)
    );
}
