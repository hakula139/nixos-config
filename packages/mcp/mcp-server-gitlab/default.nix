# ==================================================================================================
# MCP Server – GitLab (@zereight/mcp-gitlab)
# ==================================================================================================

{
  pkgs,
  lib,
}:

pkgs.buildNpmPackage rec {
  pname = "mcp-server-gitlab";
  version = "2.3.29";

  src = pkgs.fetchFromGitHub {
    owner = "zereight";
    repo = "gitlab-mcp";
    rev = "v${version}";
    hash = "sha256-iOscqSr+S6BZWCJO6vAf8UD7Ng6GDM/V75VRlsP4K2o=";
  };

  npmDepsHash = "sha256-RWqGhbVpCdrf18488gT+1TS3b5pDkE1qC5myB6UKChk=";
  nodejs = pkgs.nodejs_26;

  meta = {
    description = "MCP server for GitLab API operations (@zereight/mcp-gitlab)";
    homepage = "https://github.com/zereight/gitlab-mcp";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "mcp-gitlab";
  };
}
