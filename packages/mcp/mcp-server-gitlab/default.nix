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
  version = "2.1.46";

  src = pkgs.fetchFromGitHub {
    owner = "zereight";
    repo = "gitlab-mcp";
    rev = "v${version}";
    hash = "sha256-HpGo60cnRVzbUDxjYeqE82KFVUuJp3EuRE3jQTnnVj0=";
  };

  npmDepsHash = "sha256-I0/CbaADXGjZhzpR4KhNKCIs/16L1CifIV7lKtmRmnw=";

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
