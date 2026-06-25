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
  version = "2.1.27";

  src = pkgs.fetchFromGitHub {
    owner = "zereight";
    repo = "gitlab-mcp";
    rev = "v${version}";
    hash = "sha256-ZWcqxmAEvZHmWh+u0fa3iScz+uN8oZrIWI+Zu5VV5Mo=";
  };

  npmDepsHash = "sha256-z/Y4R95mmqu9AQHq9eU31q3Ewz9/n6aCEzz3yGEUOxc=";

  nativeBuildInputs = [ pkgs.makeBinaryWrapper ];

  postInstall = ''
    makeWrapper "${pkgs.nodejs_24}/bin/node" "$out/bin/mcp-server-gitlab" \
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
