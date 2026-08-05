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
  version = "2026.7.10";
  pyproject = true;

  src = pkgs.fetchPypi {
    pname = "mcp_server_git";
    inherit version;
    hash = "sha256-lRB7iymJgU6MIw6OSJ/u9L+k2Aykp6wWEs6gUoP/XqU=";
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
