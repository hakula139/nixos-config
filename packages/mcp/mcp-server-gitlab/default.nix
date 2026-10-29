# ==================================================================================================
# MCP Server – GitLab (@zereight/mcp-gitlab)
# ==================================================================================================

{
  pkgs,
  lib,
}:

pkgs.buildNpmPackage rec {
  pname = "mcp-server-gitlab";
  version = "2.1.46";

  src = pkgs.fetchFromGitHub {
    owner = "zereight";
    repo = "gitlab-mcp";
    rev = "v${version}";
    hash = "sha256-HpGo60cnRVzbUDxjYeqE82KFVUuJp3EuRE3jQTnnVj0=";
  };

  npmDepsHash = "sha256-I0/CbaADXGjZhzpR4KhNKCIs/16L1CifIV7lKtmRmnw=";
  nodejs = pkgs.nodejs_26;

  meta = {
    description = "MCP server for GitLab API operations (@zereight/mcp-gitlab)";
    homepage = "https://github.com/zereight/gitlab-mcp";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "mcp-gitlab";
  };
}
