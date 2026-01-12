{
  config,
  pkgs,
  lib,
  secretsDir,
  isNixOS ? false,
}:

# ==============================================================================
# MCP (Model Context Protocol)
# ==============================================================================

let
  # ----------------------------------------------------------------------------
  # Brave Search MCP
  # ----------------------------------------------------------------------------
  braveApiKeyFile = "${secretsDir}/brave-api-key";
  braveSearchBin = pkgs.writeShellScriptBin "brave-search-mcp" ''
    if [ -f "${braveApiKeyFile}" ]; then
      export BRAVE_API_KEY="$(cat ${braveApiKeyFile})"
    fi
    exec ${pkgs.nodejs}/bin/npx -y @brave/brave-search-mcp-server "$@"
  '';

  # ----------------------------------------------------------------------------
  # Context7 MCP
  # ----------------------------------------------------------------------------
  context7ApiKeyFile = "${secretsDir}/context7-api-key";
  context7Bin = pkgs.writeShellScriptBin "context7-mcp" ''
    if [ -f "${context7ApiKeyFile}" ]; then
      export CONTEXT7_API_KEY="$(cat ${context7ApiKeyFile})"
    fi
    exec ${pkgs.nodejs}/bin/npx -y @upstash/context7-mcp "$@"
  '';

  # ----------------------------------------------------------------------------
  # DeepWiki MCP
  # ----------------------------------------------------------------------------
  deepwikiBin = pkgs.writeShellScriptBin "deepwiki-mcp" ''
    exec ${pkgs.nodejs}/bin/npx -y mcp-remote https://mcp.deepwiki.com/sse --transport sse-first "$@"
  '';
in
{
  servers = {
    braveSearch = {
      command = "${braveSearchBin}/bin/brave-search-mcp";
      type = "stdio";
    };

    context7 = {
      command = "${context7Bin}/bin/context7-mcp";
      type = "stdio";
    };

    deepwiki = {
      command = "${deepwikiBin}/bin/deepwiki-mcp";
      type = "stdio";
    };
  };

  # ----------------------------------------------------------------------------
  # Secrets configuration (agenix)
  # On NixOS: system-level agenix handles decryption (modules/nixos/mcp)
  # On Darwin / standalone: home-manager agenix handles decryption
  # ----------------------------------------------------------------------------
  secrets = lib.mkIf (!isNixOS) {
    age.identityPaths = [
      "${config.home.homeDirectory}/.ssh/id_ed25519"
    ];

    age.secrets = {
      brave-api-key = {
        file = ../../../secrets/shared/brave-api-key.age;
        path = "${secretsDir}/brave-api-key";
        mode = "0400";
      };

      context7-api-key = {
        file = ../../../secrets/shared/context7-api-key.age;
        path = "${secretsDir}/context7-api-key";
        mode = "0400";
      };
    };

    home.activation.secretsDir = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      install -d -m 0700 "${secretsDir}"
    '';
  };
}
