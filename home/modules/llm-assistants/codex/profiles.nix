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
  }
  // lib.optionalAttrs cfg.enableCorpGateway {
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

  # ----------------------------------------------------------------------------
  # Profile loader
  # ----------------------------------------------------------------------------
  # tomlkit renders each override as the `-c` parser expects, including key
  # quoting and nested tables, which `to toml` and string splicing cannot.
  overridesEnv = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
  overridesScript = pkgs.copyPathToStore ./scripts/profile-overrides.py;

  loader = pkgs.writeShellScript "codex-profile-loader" (
    builtins.replaceStrings
      [
        "@caEnv@"
        "@profileOverrides@"
        "@stateDir@"
      ]
      [
        (lib.optionalString cfg.enableCorpGateway ''export CODEX_CA_CERTIFICATE="${caFile}"'')
        "${overridesEnv}/bin/python3 ${overridesScript}"
        stateDir
      ]
      (builtins.readFile ./scripts/profile-loader.sh)
  );

  # ----------------------------------------------------------------------------
  # Profile switcher
  # ----------------------------------------------------------------------------
  switch = mkProfileSwitch {
    inherit stateDir;
    name = "codex-switch";
    assistant = "Codex";
    profilesDir = configDir;
    extension = "config.toml";
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
        assertion = builtins.hasAttr cfg.defaultProfile profiles;
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
    # Activation
    # --------------------------------------------------------------------------
    # Codex persists trust and settings in the selected profile file.
    home.activation.codexMutableProfiles = lib.hm.dag.entryAfter [ "linkGeneration" ] (
      lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: settings: ''
          configFile=${lib.escapeShellArg "${configDir}/${name}.config.toml"}
          baseline=${toml.generate "codex-profile-${name}.toml" settings}

          install -d -m 0700 ${lib.escapeShellArg configDir}
          if [[ -e "$configFile" && ! -f "$configFile" ]]; then
            echo "Refusing to replace non-file Codex profile: $configFile" >&2
            exit 1
          fi

          tmpFile="$(mktemp "$configFile.XXXXXX")"
          trap 'rm -f "$tmpFile"' EXIT
          if [[ -s "$configFile" ]]; then
            ${pkgs.yq}/bin/tomlq -s -t '.[0] * .[1]' "$configFile" "$baseline" >"$tmpFile"
          else
            cp "$baseline" "$tmpFile"
          fi

          chmod 0600 "$tmpFile"
          mv "$tmpFile" "$configFile"
          trap - EXIT
        '') profiles
      )
    );

    home.activation.codexAuthProfile = lib.hm.dag.entryAfter [ "codexMutableProfiles" ] ''
      __dir=${lib.escapeShellArg stateDir}
      __link="$__dir/active-profile"
      if [[ ! -e "$__link" ]]; then
        mkdir -p "$__dir"
        ln -sf ${lib.escapeShellArg "${configDir}/${cfg.defaultProfile}.config.toml"} "$__link"
      fi
    '';
  };

  # ----------------------------------------------------------------------------
  # Exports
  # ----------------------------------------------------------------------------
  inherit loader;
}
