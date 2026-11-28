# ==================================================================================================
# Secrets Helper Library
# ==================================================================================================

{
  lib,
  secretsDir ? "/run/secrets",
}:

let
  secretsRoot = ../secrets;

  yaml = file: key: {
    sopsFile = lib.path.append secretsRoot file;
    format = "yaml";
    inherit key;
  };

  wholeFile = file: format: {
    sopsFile = lib.path.append secretsRoot file;
    inherit format;
    key = "";
  };

  bundle = file: keys: lib.genAttrs keys (yaml file);

  catalog =
    # ----------------------------------------------------------------------------------------------
    # Common secrets (all keys)
    # ----------------------------------------------------------------------------------------------
    bundle "common.yaml" [
      "cachix/auth-token"
      "github/pat"
      "gitlab/pat"
      "llm-assistants/claude-oauth-token"
      "llm-assistants/google-ai-studio-api-key"
      "llm-assistants/ikuncode-api-key"
      "llm-assistants/mcp/confluence-pat"
      "llm-assistants/mcp/context7-api-key"
      "llm-assistants/mcp/exa-api-key"
      "llm-assistants/telegram-bot-token"
      "llm-assistants/yescode-api-key"
    ]
    # ----------------------------------------------------------------------------------------------
    # Corp secrets
    # ----------------------------------------------------------------------------------------------
    // bundle "corp.yaml" [
      "devvm/proxy-url"
      "llm-assistants/corp-gateway/api-key/claude-code"
      "llm-assistants/corp-gateway/api-key/codex"
      "llm-assistants/corp-gateway/api-key/omp"
      "llm-assistants/corp-gateway/api-key/oxide-code"
      "llm-assistants/corp-gateway/api-key/prose-polish"
      "llm-assistants/corp-gateway/cachain.crt"
      "llm-assistants/corp-gateway/portal-token"
    ]
    # ----------------------------------------------------------------------------------------------
    # Server secrets
    # ----------------------------------------------------------------------------------------------
    // bundle "servers.yaml" [
      "backup/restic-password"
      "cloudflare/dns-api-token"
      "xray/reality-private-key"
    ]
    // {
      "backup/env" = wholeFile "backup.env" "dotenv";
      "builders/ssh-key" = wholeFile "builders-ssh-key" "binary";
      "xray/users.json" = wholeFile "xray/users.json" "json";
    }
    # ----------------------------------------------------------------------------------------------
    # Host-specific secrets
    # ----------------------------------------------------------------------------------------------
    // bundle "us-1.yaml" [
      "peertube/secret"
    ]
    // bundle "us-4.yaml" [
      "aria2/rpc-secret-cloudreve"
      "umami/app-secret"
      "umami/db-password"
    ]
    // {
      "peertube/env" = wholeFile "peertube.env" "dotenv";
    }
    # ----------------------------------------------------------------------------------------------
    # Workstation secrets
    # ----------------------------------------------------------------------------------------------
    // bundle "macbook.yaml" [
      "aria2/rpc-secret"
      "betterdisplay/email"
      "betterdisplay/key"
      "drivedx/license"
    ]
    // bundle "wsl.yaml" [
      "feishu/caldav/password"
      "feishu/caldav/url"
      "feishu/caldav/username"
    ]
    // bundle "workstations.yaml" [
      "mihomo/secret"
      "mihomo/subscription-url"
    ]
    // {
      "rclone/config" = wholeFile "rclone.ini" "ini";
      "wakatime/config" = wholeFile "wakatime.ini" "ini";
    };

  lookup =
    name: catalog.${name} or (throw "Unknown secret `${name}` (add it to lib/secrets.nix catalog)");

  secretPath = name: "${secretsDir}/${name}";

  mkSecret =
    {
      name,
      sopsFile ? (lookup name).sopsFile,
      format ? (lookup name).format,
      key ? (lookup name).key,
      owner ? "root",
      group ? null,
      mode ? "0400",
      path ? null,
      restartUnits ? [ ],
      reloadUnits ? [ ],
    }:
    {
      inherit
        sopsFile
        format
        key
        owner
        mode
        ;
    }
    // lib.optionalAttrs (group != null) { inherit group; }
    // lib.optionalAttrs (path != null) { inherit path; }
    // lib.optionalAttrs (restartUnits != [ ]) { inherit restartUnits; }
    // lib.optionalAttrs (reloadUnits != [ ]) { inherit reloadUnits; };
in
{
  inherit
    secretPath
    mkSecret
    ;

  mkRequiredUserSecrets =
    {
      homeConfig,
      user,
    }:
    let
      inherit (homeConfig.hakula.secrets) required;
      pathCollisions = lib.filter (g: builtins.length g > 1) (
        builtins.attrValues (builtins.groupBy (n: required.${n}.path) (builtins.attrNames required))
      );

      formatGroups = lib.concatMapStringsSep "; " (g: lib.concatStringsSep " == " g);
    in
    assert lib.assertMsg (pathCollisions == [ ]) ''
      hakula.secrets.required entries share a destination path: ${formatGroups pathCollisions}
      (each `path` override must be unique because the second decrypt would overwrite the first)
    '';

    lib.mapAttrs (
      _: spec:
      mkSecret {
        inherit (spec) name path;
        owner = user.name;
        inherit (user) group;
      }
    ) required;
}
