# ==============================================================================
# MCP Server – GitHub
# ==============================================================================

{
  pkgs,
  lib,
  ...
}:

let
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  version = "0.33.1";
  baseUrl = "https://github.com/github/github-mcp-server/releases/download/v${version}";

  sources = {
    aarch64-darwin = {
      url = "${baseUrl}/github-mcp-server_Darwin_arm64.tar.gz";
      hash = "sha256-Qq1vcb9ELE0sOvIottcWwqz+IwF6jojpxlG+FX1SOR0=";
    };
    x86_64-linux = {
      url = "${baseUrl}/github-mcp-server_Linux_x86_64.tar.gz";
      hash = "sha256-cE5WDlaeMf0+hpP1HA4AFxDZLw6PYqbRTnuLDPfez6w=";
    };
  };

  platform = pkgs.stdenv.hostPlatform.system;
  source = sources.${platform} or (throw "Unsupported platform: ${platform}");
in
pkgs.stdenv.mkDerivation {
  pname = "mcp-server-github";
  inherit version;

  src = pkgs.fetchurl {
    inherit (source) url hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals isLinux [ pkgs.autoPatchelfHook ];
  buildInputs = lib.optionals isLinux [ pkgs.stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -D -m 0755 github-mcp-server $out/bin/mcp-server-github
    runHook postInstall
  '';

  meta = {
    description = "MCP server for GitHub API operations";
    homepage = "https://github.com/github/github-mcp-server";
    license = lib.licenses.mit;
    platforms = builtins.attrNames sources;
    mainProgram = "mcp-server-github";
  };
}
