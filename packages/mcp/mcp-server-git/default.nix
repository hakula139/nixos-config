# ==============================================================================
# MCP Server – Git
# ==============================================================================

{
  pkgs,
  lib,
  ...
}:

pkgs.python3Packages.buildPythonApplication rec {
  pname = "mcp-server-git";
  version = "2026.6.16";
  pyproject = true;

  src = pkgs.fetchPypi {
    pname = "mcp_server_git";
    inherit version;
    hash = "sha256-SXJzynYSLxYxCMOjUJVWa+ORr2W0Z0qeCIckygGL0NQ=";
  };

  build-system = [ pkgs.python3Packages.hatchling ];

  dependencies = with pkgs.python3Packages; [
    click
    gitpython
    mcp
    pydantic
  ];

  # No tests in the sdist
  doCheck = false;

  meta = {
    description = "MCP server for Git repository operations";
    homepage = "https://github.com/modelcontextprotocol/servers";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "mcp-server-git";
  };
}
