# ==================================================================================================
# MCP Server – GitLab (@zereight/mcp-gitlab)
# ==================================================================================================

{
  pkgs,
  lib,
}:

pkgs.buildNpmPackage rec {
  pname = "mcp-server-gitlab";
  version = "2.3.24";

  src = pkgs.fetchFromGitHub {
    owner = "zereight";
    repo = "gitlab-mcp";
    rev = "v${version}";
    hash = "sha256-dEfFB5/dW99aShTragyy4JarQyFkIHVyOrDU9JOssz0=";
  };

  npmDepsHash = "sha256-Pb05j/jxQYQm7FkA6urEsi5lfEWFnSdRy+pDZGvilk0=";
  nodejs = pkgs.nodejs_26;

  meta = {
    description = "MCP server for GitLab API operations (@zereight/mcp-gitlab)";
    homepage = "https://github.com/zereight/gitlab-mcp";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "mcp-gitlab";
  };
}
