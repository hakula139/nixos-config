{
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# MCP Server – Git
# ==============================================================================

pkgs.python3Packages.buildPythonApplication rec {
  pname = "mcp-server-git";
  version = "2026.1.14";
  pyproject = true;

  src = pkgs.fetchPypi {
    pname = "mcp_server_git";
    inherit version;
    hash = "sha256-LNdHBMeycase174mYSDCCuiufMAeUtxsVJeQQCutK0Q=";
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
