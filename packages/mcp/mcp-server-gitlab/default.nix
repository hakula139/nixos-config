# ==================================================================================================
# MCP Server – GitLab (@zereight/mcp-gitlab)
# ==================================================================================================

{
  pkgs,
  lib,
}:

pkgs.buildNpmPackage rec {
  pname = "mcp-server-gitlab";
  version = "2.3.16";

  src = pkgs.fetchFromGitHub {
    owner = "zereight";
    repo = "gitlab-mcp";
    rev = "v${version}";
    hash = "sha256-b6vJDMCViyt5H/MJWPR2yaJLwLOLu1swDIn3WBGuO6o=";
  };

  npmDepsHash = "sha256-xnfLS38nbH1l17O0ScLdDq47BfT0LoaNbAE7NaCcf7E=";
  nodejs = pkgs.nodejs_26;

  meta = {
    description = "MCP server for GitLab API operations (@zereight/mcp-gitlab)";
    homepage = "https://github.com/zereight/gitlab-mcp";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "mcp-gitlab";
  };
}
