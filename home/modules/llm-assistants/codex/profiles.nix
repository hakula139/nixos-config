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
  # Profile switcher
  # ----------------------------------------------------------------------------
  switch = import ../shared/profile-switch.nix {
    inherit pkgs lib stateDir;
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
    assertions = [
      {
        assertion = builtins.hasAttr cfg.defaultProfile profiles;
        message = "hakula.codex.auth.defaultProfile requires its profile to be enabled";
      }
    ];
    hakula.secrets.required = lib.optionalAttrs cfg.enableCorpGateway {
      "llm-assistants/bifrost-api-key" = { };
      "llm-assistants/corp-cachain.crt" = { };
    };
    home.packages = [ switch ];
    home.file = lib.mapAttrs' (name: settings: {
      name = "${configDir}/${name}.config.toml";
      value.source = toml.generate "codex-profile-${name}.toml" settings;
    }) profiles;
    home.activation.codexAuthProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      __dir=${lib.escapeShellArg stateDir}
      __link="$__dir/active-profile"
      if [[ ! -e "$__link" ]]; then
        mkdir -p "$__dir"
        ln -sf ${lib.escapeShellArg "${configDir}/${cfg.defaultProfile}.config.toml"} "$__link"
      fi
    '';
  };

  # ----------------------------------------------------------------------------
  # Profile loader
  # ----------------------------------------------------------------------------
  loader = pkgs.writeShellScript "codex-profile-loader" (
    builtins.replaceStrings
      [ "@stateDir@" "@caFile@" ]
      [
        (lib.escapeShellArg stateDir)
        (lib.escapeShellArg (if cfg.enableCorpGateway then caFile else ""))
      ]
      (builtins.readFile ./scripts/profile-loader.sh)
  );
}
