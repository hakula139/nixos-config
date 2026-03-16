{
  pkgs,
  lib,
  ...
}:

# ==============================================================================
# MCP Server – Filesystem
# ==============================================================================

pkgs.buildNpmPackage rec {
  pname = "mcp-server-filesystem";
  version = "2026.1.14";

  src = pkgs.fetchFromGitHub {
    owner = "modelcontextprotocol";
    repo = "servers";
    rev = version;
    hash = "sha256-KL2YmxcXAVvGFuaaWQUOrbBl1JoZMtiGbjcxnFnMV8c=";
  };

  npmDepsHash = "sha256-NgRIzWZbXhfQp+1e9XUdh5/OlziVCBHH39paTaiQOKg=";

  # Monorepo: build the filesystem workspace
  npmWorkspace = "src/filesystem";

  # The `prepare` script re-runs `tsc` during prune, but devDependencies
  # (typescript) are already gone at that point.
  dontNpmPrune = true;

  # Remove broken symlinks from other workspaces in the monorepo
  postInstall = ''
    find $out -xtype l -delete
  '';

  meta = {
    description = "MCP server for filesystem operations";
    homepage = "https://github.com/modelcontextprotocol/servers";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "mcp-server-filesystem";
  };
}
