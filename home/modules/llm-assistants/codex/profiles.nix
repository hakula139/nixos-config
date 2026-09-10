# ==============================================================================
# Codex Auth Profiles
# ==============================================================================

{
  config,
  pkgs,
  lib,
  codexPkg,
  corpHosts,
  hostType,
  mkProfileSwitch,
  secretPath,
  configDir,
}:

let
  cfg = config.hakula.codex.auth;
  toml = pkgs.formats.toml { };
  stateDir = "${config.xdg.stateHome}/codex";
  tokenFile = secretPath "llm-assistants/bifrost-api-key";
  caFile = secretPath "llm-assistants/corp-cachain.crt";

  # ----------------------------------------------------------------------------
  # Model catalog
  # ----------------------------------------------------------------------------
  # The gateway's /models response is not a Codex model catalog.
  modelCatalog =
    pkgs.runCommand "codex-corp-models.json"
      {
        nativeBuildInputs = [
          codexPkg
          pkgs.jq
        ];
      }
      ''
        codex debug models --bundled | jq -e '
          .models |= map(
            select(.supported_in_api)
            | .slug |= "openai/" + .
            | if .upgrade then .upgrade.model |= "openai/" + . else . end
          )
          | select(.models != [])
        ' > "$out"
      '';

  # ----------------------------------------------------------------------------
  # Profile definitions
  # ----------------------------------------------------------------------------
  profiles = {
    official = {
      model = "gpt-6-astra";
      model_provider = "openai";
    };

    corp-gateway = {
      model = "openai/gpt-6-astra";
      model_provider = "corp-gateway";
      model_catalog_json = toString modelCatalog;
      model_auto_compact_token_limit = 250000;

      model_providers.corp-gateway = {
        name = "Corporate gateway";
        base_url = "${corpHosts.llmGatewayUrl}/v1";
        wire_api = "responses";

        auth = {
          command = "${pkgs.coreutils}/bin/cat";
          args = [ tokenFile ];
        };
      };
    };
  };

  enabledProfiles = lib.filterAttrs (
    name: _: name != "corp-gateway" || cfg.enableCorpGateway
  ) profiles;

  # ----------------------------------------------------------------------------
  # Profile switcher
  # ----------------------------------------------------------------------------
  switch = mkProfileSwitch {
    inherit stateDir;
    name = "codex-switch";
    assistant = "Codex";
    profilesDir = "${stateDir}/profiles";
    extension = "config.toml";
    configFile = "${configDir}/config.toml";
    # Provider definitions remain available when selecting another provider.
    resetKeys = lib.remove "model_providers" (
      lib.unique (lib.concatMap builtins.attrNames (builtins.attrValues profiles))
    );
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
      default = "official";
      description = "Authentication profile initialized on rebuild when no active profile exists";
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
    # --------------------------------------------------------------------------
    # Assertions
    # --------------------------------------------------------------------------
    assertions = [
      {
        assertion = builtins.hasAttr cfg.defaultProfile enabledProfiles;
        message = "hakula.codex.auth.defaultProfile requires its profile to be enabled";
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
      name = "${stateDir}/profiles/${name}.config.toml";
      value.source = toml.generate "codex-profile-${name}.toml" settings;
    }) enabledProfiles;

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
          __dir=${lib.escapeShellArg stateDir}
          __link="$__dir/active-profile"
          if [[ -L "$__link" ]]; then
            __profile="$(basename "$(readlink "$__link")" .config.toml)"
          else
            __profile=${lib.escapeShellArg cfg.defaultProfile}
          fi
          if [[ ! -f "$__dir/profiles/$__profile.config.toml" ]]; then
            __profile=${lib.escapeShellArg cfg.defaultProfile}
          fi
          ${switch}/bin/codex-switch "$__profile"
        '';
  };

  # ----------------------------------------------------------------------------
  # Exports
  # ----------------------------------------------------------------------------
  inherit stateDir;

  wrapArgs = lib.optionals cfg.enableCorpGateway [
    "--set"
    "CODEX_CA_CERTIFICATE"
    caFile
  ];
}
