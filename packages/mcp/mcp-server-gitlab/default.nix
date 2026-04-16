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
  version = "2.1.0";

  src = pkgs.fetchFromGitHub {
    owner = "zereight";
    repo = "gitlab-mcp";
    rev = "v${version}";
    hash = "sha256-jte+sMNQ0ltgQsw2IUyNb2kK+G3k3j8J/0ZSPp4i9xY=";
  };

  npmDepsHash = "sha256-D+BtfbN7Y9pM2XZ/K5LcyRDyqTlD8qoTpdkTC5asIn8=";

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
