# ==============================================================================
# MCP Server – GitLab (@zereight/mcp-gitlab)
# ==============================================================================

{
  pkgs,
  lib,
  ...
}:

pkgs.buildNpmPackage rec {
  pname = "mcp-server-gitlab";
  version = "2.0.34";

  src = pkgs.fetchFromGitHub {
    owner = "zereight";
    repo = "gitlab-mcp";
    rev = "v${version}";
    hash = "sha256-g7r0hInk4u4thR/8c8dVOqSc9VWHkx8jYa7sO6l8B+U=";
  };

  npmDepsHash = "sha256-tJou/TMZZvlPiMJgEEpE7oj3+B1XMrcCdQBDcNHsNxE=";

  nativeBuildInputs = [ pkgs.makeBinaryWrapper ];

  postInstall = ''
    makeWrapper "${pkgs.nodejs}/bin/node" "$out/bin/mcp-server-gitlab" \
      --add-flags "$out/lib/node_modules/@zereight/mcp-gitlab/build/index.js"
  '';

  meta = {
    description = "MCP server for GitLab API operations (@zereight/mcp-gitlab)";
    homepage = "https://github.com/zereight/gitlab-mcp";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "mcp-server-gitlab";
  };
}
